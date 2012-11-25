# -*- Ruby -*-
require 'rubygems/package_task'
require 'rake/testtask'
require 'rake/extensiontask'

Rake::ExtensionTask.new('trace_nums')

SO_NAME = "trace_nums.so"

desc "Test everything."
test_task = task :test => :lib do
  Rake::TestTask.new(:test) do |t|
    # TODO: fix test-lnum
    t.test_files = Dir['test/test-*.rb'] - ['test/test-lnum.rb']
    t.verbose = true
  end
end

desc "Create the core ruby-debug shared library extension"
task :lib do
  Dir.chdir("ext") do
    system("#{Gem.ruby} extconf.rb && make")
  end
end

desc "Test everything - same as test."
task :check => :test

base_spec = eval(File.read('debugger-linecache.gemspec'), binding, 'debugger-linecache.gemspec')

Gem::PackageTask.new(base_spec) do |pkg|
  pkg.need_tar = true
end

# Windows specification
win_spec = base_spec.clone
win_spec.extensions = []
## win_spec.platform = Gem::Platform::WIN32 # deprecated
win_spec.platform = 'mswin32'
win_spec.files += ["lib/#{SO_NAME}"]

desc "Create Windows Gem"
task :win32_gem do
  # Copy the win32 extension the top level directory.
  current_dir = File.expand_path(File.dirname(__FILE__))
  source = File.join(current_dir, "ext", "win32", SO_NAME)
  target = File.join(current_dir, "lib", SO_NAME)
  cp(source, target)

  # Create the gem, then move it to pkg.
  Gem::Builder.new(win_spec).build
  gem_file = "#{win_spec.name}-#{win_spec.version}-#{win_spec.platform}.gem"
  mv(gem_file, "pkg/#{gem_file}")

  # Remove win extension from top level directory.
  rm(target)
end

desc "Remove built files"
task :clean => [:clobber_package, :clobber_rdoc] do
  cd "ext" do
    if File.exists?("Makefile")
      sh "make clean"
      rm  "Makefile"
    end
    derived_files = Dir.glob(".o") + Dir.glob("*.so")
    rm derived_files unless derived_files.empty?
  end
end

task :default => [:test]
