require "mkmf"
require "debugger/ruby_core_source"

if RUBY_VERSION < '1.9'
  abort("Ruby version is too old")
end

hdrs = proc {
  have_header("vm_core.h") and have_header("version.h")
}

dir_config("ruby")
if !Debugger::RubyCoreSource.create_makefile_with_core(hdrs, "trace_nums")
  abort("Makefile creation failed.")
end
