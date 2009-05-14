#!/usr/bin/env ruby

# note that report of assertions count is
# zero. Probably because we are doing assert in
# workspace rather than Test

require File.dirname(__FILE__) + '/../lib/rubish'
require 'rubygems'
require 'pp'
require 'test/unit'
require 'thread'
gem 'thoughtbot-shoulda'
require 'shoulda'

require 'set'
  
if ARGV.first == "dev"
  TUT_ = Test::Unit::TestCase
  # create a dummy empty case to disable all tests
  # except the one we are developing
  class TUT
    def self.should(*args,&block)
      nil
    end

    def self.context(*args,&block)
      nil
    end
  end
else
  TUT = Test::Unit::TestCase
end


TEST_DIR = File.expand_path(File.dirname(__FILE__)) + "/tmp"

Rubish.new_session

WS = Rubish.session.current_workspace
#WS.extend Test::Unit::Assertions

RSH = Rubish::Context.global.derive
RSH.workspace.extend(Test::Unit::Assertions)
def rsh(&block)
  if block
    r = RSH.eval &block
    RSH.workspace.waitall
    r
  else
    RSH
  end
end

def setup_tmp
  rsh {
    rm(:rf, TEST_DIR).exec if File.exist?(TEST_DIR)
    mkdir(TEST_DIR).exec
    cd TEST_DIR
  }
end

setup_tmp


module Helper
  class << self
    def time_elapsed
      t1 = Time.now
      yield
      return Time.now - t1
    end

    def slowcat(n)
      rsh {
        lines = (1..n).to_a
        ruby("../slowcat.rb").i { |p| p.puts lines }
      }
    end

    def workspace
      # a custom workspace extended with two methods and assertions
      ws = Rubish::Workspace.new.extend Module.new {
        def foo1
          1
        end

        def foo2
          2
        end
      }, Test::Unit::Assertions
    end

    def context(i=nil,o=nil,e=nil)
      Rubish::Context.singleton.derive(nil,i,o,e)
    end
  end
end

module IOHelper
  class << self
    def created_ios
      set1 = Set.new
      set2 = Set.new
      ObjectSpace.each_object(IO) { |o| set1 << o }
      yield
      ObjectSpace.each_object(IO) { |o| set2 << o }
      set2 - set1
    end
  end
end


class Rubish::Test < TUT

  def setup
    setup_tmp
  end

  should "not have changed directory" do
    rsh {
      assert_equal TEST_DIR, pwd.first
      mkdir("dir").exec
      cd "dir" do
        assert_equal "#{TEST_DIR}/dir", pwd.first
      end
      assert_equal TEST_DIR, pwd.first
    }
  end

  should "have changed directory" do
    rsh {
      assert_equal TEST_DIR, pwd.first
      mkdir("dir").exec
      cd "dir"
      assert_equal "#{TEST_DIR}/dir", pwd.first
      cd TEST_DIR
      assert_equal TEST_DIR, pwd.first
    }
  end
end


class Rubish::Test::Workspace < TUT
  # Remember that Object#methods of Workspace
  # instances are aliased with the prefix '__'
  
  def setup
    setup_tmp
  end

  should "alias Object#methods" do
    rsh {
      ws = current_workspace
      assert_instance_of Rubish::Command, ws.class
      # it's somewhat surprising that
      # assert_instance_of still works. Probably not
      # using Object#class but case switching.
      assert_instance_of Rubish::Workspace, ws
      assert_instance_of Class, ws.__class

      # the magic methods should still be there
      assert ws.__respond_to?(:__id__)
      assert ws.__respond_to?(:__send__)

      # the magic methods should be aliased as well
      assert ws.__respond_to?(:____id__)
      assert ws.__respond_to?(:____send__)
    }
    

  end

  should "not introduce bindings to parent workspace" do
    rsh {
      parent = current_workspace
      child = parent.derive {
        def foo
          1
        end
      }
      child.eval {
        assert_not_equal parent.__object_id, child.__object_id
        # the derived workspace should have the
        # injected binding via its singleton module.
        assert_equal 1, foo
        parent.eval {
          assert_instance_of Rubish::Command, foo, "the original of derived workspace should not respond to injected bindings"
        }
      }
    }
  end
end

class Rubish::Test::Workspace::Base < TUT
  def self
    setup_tmp
  end

  should "nest with's" do
    rsh {
      c1 = self
      with {
        ws2 = self
        # redefines foo each time this block is executed
        def foo
          1
        end
        
        assert_equal c1, context.parent
        assert_instance_of Rubish::Command, ls
        assert_equal 1, foo
        with {
          assert_equal c1, context.parent.parent
          assert_equal ws2, context.workspace
          assert_equal 1, foo
          acc = []
          c2 = with(current_workspace.derive {def foo; 3 end})
          c2.eval {
            assert_equal 3, foo
          }
          c2.eval {def foo; 33; end}
          c2.eval {assert_equal 33, foo}
          
          with(c1) { # explicitly derive from a specified context
            assert_equal c1, context.parent, "should derive from given context"
          }}}
      assert_instance_of Rubish::Command, foo
    }
  end
  
end

class Rubish::Test::Executable < TUT
  def setup
    setup_tmp
  end
  
  context "io" do
    should "chomp lines for each/map" do
      rsh {
        ints = (1..100).to_a.map { |i| i.to_s }
        cat.o("output").i { |p| p.puts(ints)}.exec
        # raw access to pipe would have newlines
        cat.i("output").o do |p|
          p.each { |l| assert l.chomp!
          }
        end.exec
        # iterator would've chomped the lines
        cat.i("output").each do |l|
          assert_nil l.chomp!
        end
      }
    end
    
    should "redirect io" do
      rsh {
        ints = (1..100).to_a.map { |i| i.to_s }
        cat.o("output").i { |p| p.puts(ints)}.exec
        assert_equal ints, cat.i("output").map
        assert_equal ints, p { cat; cat; cat}.i("output").map
        assert_equal ints, cat.i { |p| p.puts(ints) }.map
      }
    end

    should "close pipes used for io redirects" do
      rsh {
        ios = IOHelper.created_ios do
          cat.i { |p| p.puts "foobar" }.o { |p| p.readlines }.exec
        end
        assert ios.all? { |io| io.closed? }
        ios = IOHelper.created_ios do
          cat.i { |p| p.puts "foobar" }.o("output").exec
        end
        assert ios.all? { |io| io.closed? }
      }
    end

    should "not close stdioe" do
      rsh {
        assert_not $stdin.closed?
        assert_not $stdout.closed?
        assert_not $stderr.closed?
        ios = IOHelper.created_ios do
          ls.exec
        end
        assert ios.empty?
        assert_not $stdin.closed?
        assert_not $stdout.closed?
        assert_not $stderr.closed?
      }
    end
    
    should "not close io if redirecting to existing IO object" do
      rsh {
        begin
          f = File.open("/dev/null","w")
          ios = IOHelper.created_ios do
            ls.o(f).exec
          end
          assert ios.empty?
          assert_not f.closed?
        ensure
          f.close
        end
      }
    end
    
  end
  
  should "head,first/tail,last" do
    rsh {
      ls_in_order = p { ls; sort :n }
      files = (1..25).to_a.map { |i| i.to_s }
      exec touch(files)
      assert_equal 25, ls.map.size
      assert_equal 1, ls.head.size
      assert_equal "1", ls_in_order.first
      assert_equal \
       (1..10).to_a.map { |i| i.to_s },
       ls_in_order.head(10)
      assert_equal 25, ls.head(100).size

      assert_equal 1, ls.tail.size
      assert_equal "25", ls_in_order.last
      assert_equal \
       (16..25).to_a.map { |i| i.to_s },
       ls_in_order.tail(10)
      assert_equal 25, ls.tail(100).size
    }
  end
  
  should "quote exec arguments" do
    rsh {
      files = ["a b","c d"]
      # without quoting
      exec touch(files)
      assert_equal 4, ls.map.size
      exec rm(files)
      assert_equal 0, ls.map.size
      # with quoting
      exec touch(files).q
      assert_equal 2, ls.map.size
      exec rm(files).q
      assert_equal 0, ls.map.size
      
    }
  end
  
end


class Rubish::Test::Context < TUT
  def setup
    setup_tmp
  end

  should "stack contexts" do
    c1 = Helper.context(nil,"c1_out")
    c2 = Helper.context(nil,"c2_out")
    c1.eval {
      # the following "context" is a binding
      # introduced by the default workspace. It
      # should point to the current active context.
      assert_instance_of Rubish::Context, context
      assert_equal Rubish::Context.current, context
      assert_equal Rubish::Context.singleton, context.parent
      assert_equal c1, context
      assert_equal "c1_out", context.o
      c2.eval {
        assert_equal c2, context
        assert_equal "c2_out", context.o
        assert_equal Rubish::Context.singleton, context.parent
      }
    }
  end
  
  should "use context specific workspace" do
    Helper.context.eval {
      assert_equal 1, foo1
      assert_equal 2, foo2
      cmd = ls
      assert_instance_of Rubish::Command, cmd
    }
  end

  should "use context specific IO" do
    output =  "context-output"
    c = Helper.context(nil,output)
    c.eval {
      
      assert_equal output, Rubish::Context.current.o
      cat.i { |p| p.puts 1}.exec
      assert_equal 1, cat.i(output).first.to_i
    }
  end

  should "set parent context when deriving" do
    c1 = Rubish::Context.singleton
    c11 = c1.derive
    c111 = c11.derive
    c12 = c1.derive
    c2 = Rubish::Context.new(WS)

    assert_nil c1.parent
    assert_equal c1, c11.parent
    assert_equal c1, c12.parent
    assert_equal c11, c111.parent

    assert_nil c2.parent
    
    
  end

  should "derive context, using the context attributes of the original" do
    i1 = "i1"
    o1 = "o1"
    e1 = "e1"
    orig = Helper.context(i1, o1, e1)
    derived = orig.derive

    assert_not_equal orig, derived
    assert_equal orig.workspace, derived.workspace
    assert_equal orig.i, derived.i
    assert_equal orig.o, derived.o
    assert_equal orig.err, derived.err
    assert_not_equal orig.job_control, derived.job_control,  "derived context should have its own job control"

    # make changes to the derived context
    derived.i = "i2"
    derived.o = "o2"
    derived.err = "e2"

    derived.workspace = WS.derive {
      def foo
        1
      end
    }
    assert_equal 1, derived.eval { foo }

    # orig should not have changed
    assert_equal i1, orig.i
    assert_equal o1, orig.o
    assert_equal e1, orig.err
    assert_instance_of Rubish::Command, orig.eval { foo }
    
  end

  should "use context specific job_controls" do
    rsh {
      jc1 = job_control
      slow = Helper.slowcat(1)
      j1 = slow.exec!

      jc2, j2 = nil 
      with {
        jc2 = job_control 
        j2 = slow.exec!
      }

      assert_not_equal jc1, jc2
      
      assert_equal [j1], jc1.jobs
      assert_equal [j2], jc2.jobs

      t = Helper.time_elapsed {
        jc1.waitall
        jc2.waitall
      }

      assert_in_delta 1, t, 0.1
      assert jc1.jobs.empty?
      assert jc2.jobs.empty?
    }
  end
  
end

class Rubish::Test::Job < TUT
  
  def setup
    setup_tmp
  end

  should "belong to job_control" do
    rsh {
      jc1 = job_control
      j1 = ls.exec!
      j2, jc2 = nil
      with {
        jc2 = job_control
      }

      assert_equal jc1, j1.job_control
      assert_not_equal jc2, j1.job_control
      
      assert_raise(Rubish::Error) {
        jc2.remove(j1)
      }
      
    }
  end

  should "set result to array of exit statuses" do
    rsh {
      ls.exec.result.each { |status|
        assert_instance_of Process::Status, status
        assert_equal 0, status.exitstatus
      }
    }
  end

  should "map in parrallel to different array" do
    slow = Helper.slowcat(1)
    a1, a2, a3 = [[],[],[]]
    j1 = slow.map! a1
    j2 = slow.map! a2
    j3 = slow.map! a3
    js = [j1,j2,j3]
    t = Helper.time_elapsed {
      js.each { |j| j.wait }
    }
    assert_in_delta 1, t, 0.1
    assert j1.ok? && j2.ok? && j3.ok?
    rs = [a1,a2,a3]
    # each result should be an array of sized 3
    assert(rs.all? { |r| r.size == 1 })
    # should be accumulated into different arrays
    assert_equal(3,rs.map{|r| r.object_id }.uniq.size)
  end

  should "map in parrallel to thread safe queue" do
    slow = Helper.slowcat(1)
    acc = Queue.new
    j1 = slow.map! acc
    j2 = slow.map! acc
    j3 = slow.map! acc
    js = [j1,j2,j3]
    t = Helper.time_elapsed {
      j1.wait; j2.wait; j3.wait
    }
    assert_in_delta 1, t, 0.1
    assert j1.ok? && j2.ok? && j3.ok?
    # each result should be an array of sized 3
    assert_equal 3, acc.size
  end

  should "wait for job" do
    job = Helper.slowcat(1).exec!
    assert_equal false, job.done?
    assert_equal false, job.ok?
    t = Helper.time_elapsed { job.wait }
    assert_in_delta 0.1, t, 1
    assert_equal true, job.done?
    assert_equal true, job.ok?
  end
  
  should "raise when waited twice" do
    assert_raise(Rubish::Error) {
      rsh { ls.exec.wait }
    }
    assert_raise(Rubish::Error) {
      rsh { ls.exec!.wait.wait }
    }
  end

  should "kill a job" do
    acc = []
    t = Helper.time_elapsed {
      job = Helper.slowcat(10).map!(acc)
      sleep(2)
      job.stop!
    }
    assert_in_delta 2, acc.size, 1, "expects to get roughly two lines out before killing process"
    assert_in_delta 2, t, 0.1
    
  end
  
end


class Rubish::Test::JobControl < TUT

  should "use job control" do
    rsh {
      slow = Helper.slowcat(1).o "/dev/null"
      job1 = slow.exec!
      job2 = slow.exec!
      assert_kind_of Rubish::Job, job1
      assert_kind_of Rubish::Job, job2
      assert_equal 2, jobs.size
      assert_instance_of Array, jobs
      assert jobs.include?(job1)
      assert jobs.include?(job2)
      job1.wait
      job2.wait
      assert jobs.empty?, "expects jobs to empty"
    }
  end
  
  should "job control waitall" do
    rsh {
      puts "slowcat 1 * 3 lines in sequence"
      slow = Helper.slowcat(1)
      cats = (1..3).to_a.map { slow.exec! }
      assert_equal 3, jobs.size
      assert cats.all? { |cat| jobs.include?(cat) }
      t = Helper.time_elapsed { waitall }
      assert_in_delta 1, t, 0.1
      assert jobs.empty?
    }
  end

end


# class Rubish::Test::Batch < TUT
  
# end
