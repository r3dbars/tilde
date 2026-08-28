require 'json'
require 'open3'
require 'net/http'
require 'time'

def numeric_metrics(body)
  body.lines.each_with_object({}) do |line, values|
    # No arbitrary labels or text are retained.
    match = line.match(/\A(llamacpp:[a-zA-Z0-9_:]+)\s+([0-9.eE+\-]+)\s*\z/)
    next unless match
    value = Float(match[2]) rescue nil
    values[match[1]] = value if value && value.finite?
  end
end

def compatible_identity(before, after)
  before && before == after ? before : nil
end

def canonical_uuid(value)
  text = value.downcase
  raise 'invalid campaign UUID' unless text.match?(/\A[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\z/)
  text
end

def running_identity(database, campaign_id)
  return nil unless File.exist?(database)
  id = canonical_uuid(campaign_id)
  query = "SELECT trial_id,block_index FROM work_item WHERE campaign_id='#{id}' AND status='running' GROUP BY trial_id,block_index;"
  out, status = Open3.capture2('/usr/bin/sqlite3', '-readonly', '-separator', '|', database, query,
    err: File::NULL)
  rows = out.lines.map { |line| line.strip.split('|') }
  status.success? && rows.length == 1 ? [rows[0][0], rows[0][1].to_i] : nil
end

if ARGV == ['--self-test']
  raise unless numeric_metrics("llamacpp:tokens_predicted_total 12\n# private\nother_metric 99\n") ==
    {'llamacpp:tokens_predicted_total' => 12.0}
  raise unless numeric_metrics("llamacpp:bad NaN\nllamacpp:label{x=1} 2\n").empty?
  raise unless compatible_identity(['off', 2], ['off', 2]) == ['off', 2]
  raise unless compatible_identity(['off', 2], ['on', 2]).nil?
  raise unless compatible_identity(nil, nil).nil?
  require 'tmpdir'
  Dir.mktmpdir('tilde-cache-monitor-test-') do |temporary|
    database = File.join(temporary, 'test.sqlite3')
    id = 'DB5CAC8F-AFC0-4878-9DCD-DE799939EEF5'
    sql = "CREATE TABLE work_item(campaign_id TEXT,trial_id TEXT,block_index INTEGER,status TEXT); INSERT INTO work_item VALUES('#{canonical_uuid(id)}','off',2,'running');"
    _, status = Open3.capture2('/usr/bin/sqlite3', database, sql)
    raise unless status.success?
    raise unless running_identity(database, id) == ['off', 2]
    _, status = Open3.capture2('/usr/bin/sqlite3', database,
      "INSERT INTO work_item VALUES('#{canonical_uuid(id)}','on',2,'running');")
    raise unless status.success? && running_identity(database, id).nil?
  end
  puts 'PASS: numeric metrics, transition exclusion, and real SQLite mixed-case UUID attribution'
  exit
end

dir, source = ARGV
abort 'expected campaign directory and frozen source' unless dir && source
File.umask(0077)
campaign_path = File.join(dir, 'campaign.json')
database = File.join(dir, 'research.sqlite3')
campaign_id = canonical_uuid(JSON.parse(File.read(campaign_path)).fetch('id'))
abort 'refusing to overwrite study execution' if File.exist?(File.join(dir, 'monitor.jsonl'))
runner = File.join(source, '.build/debug/tilde-lab')

# Refuse implicit resume, mutation, or a second execution.
config = JSON.parse(File.read(campaign_path))
abort 'full study must have a 4.75-hour cap' unless config.fetch('budget').fetch('maximumHours') == 4.75
abort 'expected two arms' unless config.fetch('manifest').fetch('arms').length == 2
power, = Open3.capture2('/usr/bin/pmset', '-g', 'batt')
abort 'AC power required' unless power.include?("'AC Power'")
check, check_status = Open3.capture2('/usr/bin/git', '-C', source, 'status', '--porcelain')
abort 'source must remain clean' unless check_status.success? && check.empty?
provenance = JSON.parse(File.read(File.join(dir, 'frozen.json')))
require 'digest'
abort 'campaign hash changed' unless Digest::SHA256.file(campaign_path).hexdigest == provenance.fetch('campaign_sha256')
abort 'runner hash changed' unless Digest::SHA256.file(runner).hexdigest == provenance.fetch('runner_sha256')
abort 'monitor hash changed' unless Digest::SHA256.file(__FILE__).hexdigest == provenance.fetch('monitor_sha256')
head, head_status = Open3.capture2('/usr/bin/git', '-C', source, 'rev-parse', 'HEAD')
abort 'source commit changed' unless head_status.success? && head.strip == provenance.fetch('source_commit')
%w[model helper].each do |asset|
  path = config.fetch('model').fetch("#{asset}Path")
  abort "#{asset} hash changed" unless Digest::SHA256.file(path).hexdigest == provenance.fetch("#{asset}_sha256")
end
lock = File.open(File.join(dir, 'execution.lock'), File::WRONLY | File::CREAT, 0600)
abort 'another supervisor is active' unless lock.flock(File::LOCK_EX | File::LOCK_NB)
if File.exist?(database)
  state, state_status = Open3.capture2('/usr/bin/sqlite3', '-readonly', database, 'SELECT status FROM campaign;', err: File::NULL)
  abort 'existing campaign cannot be relaunched' unless state_status.success? && state.strip.empty?
end

started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
pid = Process.spawn(runner, 'run', campaign_path, '--database', database,
  '--no-cache', chdir: source, pgroup: true,
  out: File.join(dir, 'run.log'), err: [:child, :out])
Signal.trap('TERM') { exit 1 }
Signal.trap('INT') { exit 1 }
at_exit do
  begin
    Process.kill('TERM', -pid) if Process.getpgid(pid) == pid
  rescue Errno::ESRCH
  end
end
File.write(File.join(dir, 'runner.pid'), "#{pid}\n")
puts "study runner started pid=#{pid}"
$stdout.flush
stop_reason = nil
stop_sent_at = nil
last_power_check = 0
last_progress = 0
known_helpers = []
status = nil
File.open(File.join(dir, 'monitor.jsonl'), File::WRONLY | File::CREAT | File::EXCL, 0600) do |log|
  loop do
    ended = Process.waitpid2(pid, Process::WNOHANG)
    if ended
      status = ended[1]
      break
    end
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    before = running_identity(database, campaign_id)
    table, = Open3.capture2('/bin/ps', '-axo', 'pid=,ppid=,rss=,comm=')
    helpers = table.lines.map do |line|
      fields = line.strip.split(/\s+/, 4)
      next unless fields.length == 4 && fields[1].to_i == pid && fields[3].end_with?('/llama-server')
      {pid: fields[0].to_i, rss_kib: fields[2].to_i}
    end.compact
    native = {}
    if helpers.length == 1
      child = helpers.first
      known_helpers |= [child[:pid]]
      args, = Open3.capture2('/bin/ps', '-p', child[:pid].to_s, '-o', 'args=')
      port_match = args.match(/--port\s+(\d+)/)
      if port_match
        begin
          http = Net::HTTP.new('127.0.0.1', port_match[1].to_i, nil)
          http.open_timeout = 0.3
          http.read_timeout = 0.3
          response = http.get('/metrics')
          native = numeric_metrics(response.body) if response.code == '200'
        rescue StandardError
          # Missing metrics remain missing, never replaced by zero.
        end
      end
      stop_reason ||= 'helper-rss-ceiling' if child[:rss_kib] > 16 * 1024 * 1024
    elsif helpers.length > 1
      stop_reason ||= 'unexpected-multiple-owned-helpers'
    end
    after = running_identity(database, campaign_id)
    identity = helpers.length == 1 ? compatible_identity(before, after) : nil
    row = {at: Time.now.utc.iso8601(6), elapsed_seconds: elapsed.round(3),
      helpers: helpers, arm: identity && identity[0], block: identity && identity[1],
      native_metrics: native}
    if elapsed - last_power_check >= 10
      power, = Open3.capture2('/usr/bin/pmset', '-g', 'batt')
      percent = power[/\b(\d+)%/, 1]&.to_i
      row[:battery_percent] = percent
      row[:on_battery] = power.include?("'Battery Power'")
      stop_reason ||= 'battery-below-25-percent' if percent && percent < 25
      stop_reason ||= 'ac-power-lost' unless power.include?("'AC Power'")
      last_power_check = elapsed
    end
    # The CLI owns the 17100-second active budget. This is an outer watchdog
    # for a stuck preflight or failed cleanup; it never extends the time budget.
    stop_reason ||= 'outer-watchdog' if elapsed >= 17100
    # Numeric CPU load from other same-device inference helpers is a
    # contention marker, never a request or writing log.
    competitors, = Open3.capture2('/bin/ps', '-axo', 'pid=,ppid=,%cpu=,comm=')
    row[:other_helper_cpu_percent] = competitors.lines.sum do |line|
      fields = line.strip.split(/\s+/, 4)
      fields.length == 4 && fields[1].to_i != pid &&
        fields[3].end_with?('/llama-server') ? fields[2].to_f : 0.0
    end
    if stop_reason && !stop_sent_at
      Process.kill('INT', pid) rescue nil
      stop_sent_at = elapsed
    elsif stop_sent_at && elapsed - stop_sent_at >= 5
      # Only the new runner-owned process group; never the daily preview.
      Process.kill('TERM', -pid) rescue nil
    end
    row[:stop_reason] = stop_reason if stop_reason
    log.puts(JSON.generate(row))
    log.flush
    if elapsed - last_progress >= 60
      puts "study elapsed=#{elapsed.round}s owned_helpers=#{helpers.length} arm=#{row[:arm] || 'transition'}"
      $stdout.flush
      last_progress = elapsed
    end
    sleep 1
  end
end
File.write(File.join(dir, 'monitor-result.json'), JSON.pretty_generate(
  campaign_id: campaign_id, runner_pid: pid, helper_pids: known_helpers,
  exit_status: status.exitstatus, signal: status.termsig, stop_reason: stop_reason,
  elapsed_seconds: (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(3)
) + "\n")
puts "study ended exit=#{status.exitstatus.inspect} signal=#{status.termsig.inspect} stop=#{stop_reason.inspect}"
exit(status.success? ? 0 : 1)
