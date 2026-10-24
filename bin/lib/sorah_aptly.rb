# Shared helpers for bin/sorah-aptly-* scripts.
require 'json'
require 'open3'
require 'shellwords'

module SorahAptly
  ARCHITECTURES = 'amd64,arm64,source'

  # Repositories are named "#{name}-#{distro}" and published to "s3:#{name}:" as distribution "#{distro}".
  Target = Data.define(:name, :gpg_key, :label, :origin) do
    def endpoint = "s3:#{name}:"
    def repo_name(distro) = "#{name}-#{distro}"

    def publish_flags
      [
        *("-label=#{label}" unless label.empty?),
        *("-origin=#{origin}" unless origin.empty?),
      ]
    end
  end

  TARGETS = {
    'nkmideb' => Target.new(name: 'nkmideb', gpg_key: '3D38A16556C57C162F0D6F5AA3599225C3FF3305', label: 'Nkmideb', origin: 'Nkmideb'),
    'sorah-ruby' => Target.new(name: 'sorah-ruby', gpg_key: '805E57E2327EE86EB8180E0669CEB9D53F0F56A8', label: '', origin: ''),
  }
  TARGET_ALIASES = {'ruby' => 'sorah-ruby'}

  def self.target(name)
    TARGETS.fetch(TARGET_ALIASES.fetch(name, name)) do
      abort "unknown target #{name.inspect}; available: #{TARGETS.keys.join(', ')}"
    end
  end

  def self.capture(*cmd)
    out, err, status = Open3.capture3('aptly', *cmd)
    raise "aptly #{cmd.shelljoin} failed: #{err.strip}" unless status.success?
    out
  end

  def self.run(*cmd, dry_run: false)
    puts "#{dry_run ? '(dry-run) ' : ''}$ aptly #{cmd.shelljoin}"
    return if dry_run
    system('aptly', *cmd, exception: true)
  end

  # Distros with a local repo, including "-proposed" ones.
  def self.repo_distros(target)
    prefix = "#{target.name}-"
    capture('repo', 'list', '-raw').lines(chomp: true).filter_map { _1.delete_prefix(prefix) if _1.start_with?(prefix) }
  end

  def self.published_distros(target)
    # Lines look like "s3:nkmideb:. bionic".
    capture('publish', 'list', '-raw').lines(chomp: true).filter_map do |line|
      storage, distro = line.split(' ', 2)
      distro if storage == "#{target.endpoint}."
    end
  end

  # Differences between an existing publish and what the target would publish, as human-readable strings.
  def self.publish_drift(target, distro)
    published = JSON.parse(capture('publish', 'show', '-json', distro, target.endpoint))
    expected = {
      'Architectures' => ARCHITECTURES.split(',').sort,
      'Label' => target.label,
      'Origin' => target.origin,
      'Sources' => ["main=#{target.repo_name(distro)}"],
    }
    actual = {
      'Architectures' => published.fetch('Architectures').sort,
      'Label' => published.fetch('Label'),
      'Origin' => published.fetch('Origin'),
      'Sources' => published.fetch('Sources').map { "#{_1.fetch('Component')}=#{_1.fetch('Name')}" },
    }
    expected.filter_map do |key, value|
      "#{key}: #{actual.fetch(key).inspect}, expected #{value.inspect}" unless actual.fetch(key) == value
    end
  end

  def self.search(repo, query)
    out, err, status = Open3.capture3('aptly', 'repo', 'search', repo, query)
    return out.lines(chomp: true) if status.success?
    return [] if err.include?('no results')
    raise "aptly repo search #{repo} #{query.shellescape} failed: #{err.strip}"
  end

  def self.publish_update(target, distro, dry_run: false)
    run('publish', 'update', "-gpg-key=#{target.gpg_key}", distro, target.endpoint, dry_run:)
  end

  # Picks the distro from a "~distro" version suffix, e.g. foo_1.0-0nkmi1~noble_amd64.deb or foo_1.0-0nkmi1~noble.dsc
  def self.distro_from_filename(path)
    File.basename(path)[/~([a-z]+)\d*(?:_[^_]+\.d?deb|\.dsc)\z/, 1]
  end

  def self.parse_distros(str) = str.split(',').map(&:strip).reject(&:empty?)
end
