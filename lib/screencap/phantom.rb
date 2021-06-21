require 'cgi'
require 'timeout'

module Screencap
  class Phantom
    RASTERIZE = SCREENCAP_ROOT.join('screencap', 'raster.js')

    def self.rasterize(url, path, args = {})
      params = {
        url: CGI::escape(url),
        output: path
      }.merge(args).collect {|k,v| "#{k}=#{v}"}
      puts RASTERIZE.to_s, params if(args[:debug])

      if args[:cutoffWait]
        # The RASTERIZE script uses "cutoffWait" to force terminate
        # execution, but this will not trigger if PhantomJS crashes.
        # Add an arbitrary amount of time to "cutoffWait" to give
        # the RASTERIZE script time to terminate itself in normal
        # situations.
        begin
          Timeout.timeout((args[:cutoffWait] / 1000) + 5) do
            phantomjs_run(url, params, args)
          end
        rescue Timeout::Error => e
          raise Screencap::Error.new(e)
        end
      else
        phantomjs_run(url, params, args)
      end
    end

    # Custom implementation of Phantomjs.run to manually close the IO
    # stream. Ruby timeout will not work with Phantomjs.run due its use
    # IO.popen in block form (https://stackoverflow.com/a/17241050).
    def self.phantomjs_run(url, phantomjs_params, options)
      io = IO.popen([Phantomjs.path, RASTERIZE.to_s, *phantomjs_params])

      result = io.read
      puts result if options[:debug]

      raise Screencap::Error, "Could not load URL #{url}" if result.match /Unable to load/
    ensure
      Process.kill('TERM', io.pid)
      io.close
    end

    def quoted_args(args)
      args.map{|x| quoted_arg(x)}
    end

    def quoted_arg(arg)
      return arg if arg.starts_with?("'") && arg.ends_with?("'")
      arg = "'" + arg unless arg.starts_with?("'")
      arg = arg + "'" unless arg.ends_with?("'")
      arg
    end
  end
end
