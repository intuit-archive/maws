class CommandLoader
  def initialize(config)
    @config = config
  end

  def load
    # assumes command file is known to exist already
    @config.command_name = @config.command_line.command_name
    command_path = @config.config.available_commands[@config.command_name]
    class_constant_name = constantize_file_name(@config.command_name)

    require command_path

    begin
      @config.command_class = Object.const_get(class_constant_name)
    rescue NameError
      error "Could not load class #{class_constant_name} from the file #{command_path}"
      exit(1)
    end
  end

  private

  def constantize_file_name(dashed)
    dashed.split('-').map {|w| w.capitalize}.join
  end

end