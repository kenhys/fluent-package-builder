#!/opt/td-agent/bin/ruby

require "fileutils"
require "tmpdir"
require_relative "config"

STUB_DIR=File.join(Dir.tmpdir, "stubs")
FLUENT_PACKAGE_DIR="/opt/#{PACKAGE_DIR}"
SHARE_DIR=File.join(FLUENT_PACKAGE_DIR, "share")

# Copy Gemfile* to temporary directory to avoid permission error with bundle binstubs
FileUtils.mkdir_p(STUB_DIR)
%w(Gemfile Gemfile.lock config.rb).each do |name|
  FileUtils.cp(File.join(SHARE_DIR, name), STUB_DIR)
end

Dir.chdir(STUB_DIR) do
  # Install all stub files which is described in Gemfile
  gem_command = File.join(FLUENT_PACKAGE_DIR, "bin/gem")
  puts "::group::Create stub files" if ENV["CI"]
  system(gem_command, "pristine", "--all", "--only-executables", "--bindir", "#{STUB_DIR}/bin")
  puts "::endgroup::" if ENV["CI"]

  required_stub_paths = Dir.glob("#{STUB_DIR}/bin/*").each do |stub|
    basename = File.basename(stub)
    File.join(FLUENT_PACKAGE_DIR, "bin/#{basename}")
  end

  all_stub_exists = required_stub_paths.each.all? do |stub_path|
    File.exist?(stub_path)
  end

  if all_stub_exists
    required_stub_paths.map do |stub|
      basename = File.basename(stub)
      path = File.join(FLUENT_PACKAGE_DIR, "bin/#{basename}")
      puts "OK: #{path} exists"
    end
  else
    puts "ERROR: required stub files are not exist"
    required_stub_paths.each do |stub_path|
      unless File.exist?(stub_path)
        puts "Not found: <#{stub_path}>"
      end
    end
    exit 1
  end
end
exit 0
