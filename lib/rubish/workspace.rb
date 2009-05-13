class Rubish::Workspace < Rubish::Mu

  class << self
    # this is the default workspace (used by the singleton context
    def singleton
      @singleton ||= Rubish::Workspace.new
    end

    alias_method :global, :singleton
  end

  module Base
    include Rubish::Session::JobControl

    # TODO move this to context?
    def cd(dir,&block)
      if block
        begin
          old_dir = FileUtils.pwd
          FileUtils.cd File.expand_path(dir)
          # hmmm.. calling instance_eval has weird effects, dunno why
          #self.instance_eval &block
          return block.call
        ensure
          FileUtils.cd old_dir
        end
      else
        FileUtils.cd File.expand_path(dir)
      end
    end

    def cmd(method,*args)
      Rubish::Command.new(method,args)
    end

    def p(&block)
      # self is the workspace
      Rubish::Pipe.new(self,&block)
    end

    def exec(*exes)
      __exec(:exec,exes)
    end

    def exec!(*exes)
      __exec(:exec!,exes)
    end

    # current context on the dynamic context stack
    def context
      Rubish::Context.current
    end

    # TODO should clone a context (as well as workspace)
    def scope(ws=nil,i=nil,o=nil,e=nil)
      Rubish::Context.new(current.workspace,i,o,e)
    end

    private

    def __exec(exec_method,exes)
      exes.map do |exe|
        raise "not an exeuctable: #{exe}" unless exe.is_a?(Rubish::Executable)
        exe.send(exec_method)
      end
    end
    
  end

  include Base

  attr_accessor :command_factory_hook
  
  def initialize
    # @vars = {}
    # this is a hack for pipe... dunno if there's a better way to do it.
    @command_factory_hook = nil
    @modules = []
  end

  def extend(*modules,&block)
    @modules.concat modules
    modules.each do |m|
      self.__extend(m)
    end
    # extend with anonymous module
    if block
      mod = Module.new(&block)
      self.__extend mod
      @modules << mod
    end
    self
  end

  # creates a cloned workspace
  def derive(*modules,&block)
    # parent_modules = self.modules.dup
#     new_ws = Rubish::Workspace.new
#     new_ws.extend(*parent_modules)
    new_ws = self.__clone
    new_ws.extend(*modules,&block)
  end

  def eval(__string=nil,&__block)
    raise "should be either a string or a block" if __string && __block
    if __block
      self.__instance_eval(&__block) 
    else
      self.__instance_eval(__string)
    end
  end

  def method_missing(method,*args,&block)
    cmd = Rubish::Command.new(method,args)
    if @command_factory_hook.is_a?(Proc)
      @command_factory_hook.call(cmd)
    else
      cmd
    end
  end

  def methods
    self.__methods.reject { |m| m =~ /^__/ }
  end

  def inspect
    self.__inspect
  end
  
end
