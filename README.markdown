# Rubish

Rubish is a shell in Ruby. It is *object
oriented*, and it only uses Ruby's own syntax (*no
metasyntax* of its own). Rubish is pronounced
Roobish, as opposed to Rubbish, unlike Bash.

# Getting Started

Fire up an irb, and start Rubish

    $ irb -rrubish
    irb> Rubish.repl
    rbh> date
    Tue Mar 17 17:06:04 PDT 2009
    rbh> uname :svrm
    Linux 2.6.24-16-generic #1 SMP Thu Apr 10 13:23:42 UTC 2008 i686
    
A few tips upfront. Sometimes Rubish could mess up
your terminal. If that happens, try hitting `C-c`
and `C-d` to get back to Bash, then,

    $ reset

to reset your terminal. Also, Rubish doesn't have
shell history. But it uses the readline library,
so you can use its history mechanism. `C-r <string>`
 to match a previously entered line with
string.

# Overview

Rubish's Executable class provides a common API
for IO redirection and output processing. The
subclasses are,

    Command
      A unix command.
    Pipe
      A pipe line of unix commands
    Awk
    Sed
    Batch
      An arbitrary block of code. Like subshell.

# Command

Rubish REPL takes a line and `instance_eval` it
with the shell object (a `Rubish::Context`). If
the method is undefined, they call is translated
into an Executable (`Rubish::Command`) object with
`method_missing`.

    rbh> ls
    awk.rb	command_builder.rb  command.rb executable.rb  LICENSE	pipe.rb  README.textile rubish.rb  sed.rb  session.rb	streamer.rb

    # ls evaluates to a Rubish::Command object, which
    # is a subclass of Rubish::Executable
    rbh> ls.inspect
    "#<Rubish::Command::ShellCommand:0xb7ac297c @args=\"\", @status=nil, @cmd=\"ls \">"

    # you can store a command in an instance variable
    rbh> @cmd = ls; nil
    nil
    # if the shell evaluates to a command, the shell
    # calls the exec method on it.
    rbh> @cmd # same as @cmd.exec
    awk.rb	command_builder.rb  command.rb	executable.rb  LICENSE	pipe.rb  README.textile  rubish.rb  sed.rb  session.rb	streamer.rb
    rbh> @cmd
    awk.rb	command_builder.rb  command.rb	executable.rb  LICENSE	pipe.rb  README.textile  rubish.rb  sed.rb  session.rb	streamer.rb

You can invoke a command with arguments of
`String`, `Symbol`, or `Array` (of `String`,
`Symbol`, or `Array` (recursively)). A `String`
argument is taken as it is. A `Symbol` is
translated to a flag (:flag => -flag). Arguments
in an `Array` are treated likewise. Finally, all
the arguments are flatten and joined together.

The followings are equivalent,

    rbh> ls :l, "awk.rb", "sed.rb"
    rbh> ls "-l awk.rb sed.rb"
    rbh> ls :l, %w(awk.rb sed.rb)

# Pipe

    rbh> p { ls ; tr "a-z A-Z" }
    AWK.RB
    COMMAND_BUILDER.RB
    COMMAND.RB
    EXECUTABLE.RB
    LICENSE
    PIPE.RB
    README.TEXTILE
    RUBISH.RB
    SED.RB
    SESSION.RB
    STREAMER.RB

Pipes are first class values:

    rbh> @pipe = p { ls ; tr "a-z A-Z" }; nil
    # again, we return nil so @pipe doesn't get executed.
    rbh> @pipe
    # execute @pipe once
    rbh> @pipe
    # execute @pipe again

# IO redirections
  
IO redirections are done by methods defined in
`Rubish::Executable`.

    Rubish::Executable#i(io=nil)
      Set the $stdin of the executable when
      it is executed. If called without an argument,
      return the executable's IO object.
    Rubish::Executable#o(io=nil)
      Ditto for $stdout
    Rubish::Executable#err(io=nil)
      Ditto for $stderr


    rbh> ls.o("ls-result")
    rbh> cat.i("ls-result")
    awk.rb
    command_builder.rb
    command.rb
    executable.rb
    LICENSE
    ls-result
    pipe.rb
    README.textile
    rubish.rb
    sed.rb
    session.rb
    streamer.rb

Rubish can take 4 kinds of objects for
IO. `String` (used as a file path), `Integer`
(used as file descriptor), `IO` object, or a ruby
block. Using the a block for IO, the block
receives a pipe connecting it to the command, for
reading or writing.

    # pump numbers into cat
    rbh> cat.i { |p| p.puts((1..5).to_a) }
    1
    2
    3
    4
    5

    # upcase all filenames
    rbh> ls.o { |p| p.each_line {|l| puts l.upcase} }
    AWK.RB
    COMMAND_BUILDER.RB
    COMMAND.RB
    EXECUTABLE.RB
    LICENSE
    LS-RESULT
    PIPE.RB
    README.TEXTILE
    RUBISH.RB
    SED.RB
    SESSION.RB
    STREAMER.RB

    # kinda funny, pump numbers into cat, then pull
    # them out again.
    rbh> cat.i { |p| p.puts((1..10).to_a) }.o {|p| p.each_line {|l| puts l.to_i+100 }}
    101
    102
    103
    104
    105
    106
    107
    108
    109
    110

The input and output blocks are executed in their
own threads. So careful.

# Rubish with Ruby

Rubish is designed so it's easy to interface Unix
command with Ruby.

    Rubish::Executable#each(&block)
      yield each line of output to a block.
    Rubish::Executable#map(&block)
      Like #each, but collect the values returned by
      the block. If no block given, collect each
      line of the output.
    Rubish::Executable#head(n=1,&block)
      Process the first n lines of output
      with a block.
    Rubish::Executable#tail(n=1,&block)
      Process the last n lines of output
      with a block.
    Rubish::Executable#first
      Returns first line of output.
    Rubish::Executable#last
      Returns last line of output.

Since this is Ruby, there's no crazy metasyntatic
issues when you want to process the output lines.

    # print filename and its extension side by side.
    rbh> ls.each { |f| puts "#{f}\t#{File.extname(f)}" }
    address.rb	.rb
    awk.output	.output
    awk.rb	.rb
    command_builder.rb	.rb
    command.rb	.rb
    executable.rb	.rb
    foo	
    foobar	
    foo.bar	.bar
    foo.rb	.rb
    LICENSE	
    my.rb	.rb
    pipe.rb	.rb
    #README.textile#	.textile#
    README.textile	.textile
    rubish.rb	.rb
    ruby-termios-0.9.5	.5
    ruby-termios-0.9.5.tar.gz	.gz
    #sed.rb#	.rb#
    sed.rb	.rb
    session.rb	.rb
    streamer.rb	.rb
    todo	
    util

You can execute a command within the each block.

    rbh> ls.each { |f| wc(f).exec  }
      64  131 1013 awk.rb
     116  202 1914 command_builder.rb
      56  113 1034 command.rb
     196  563 4388 executable.rb
      24  217 1469 LICENSE
     12  12 132 ls-result
      78  245 1917 pipe.rb
     142  544 3388 README.textile
     107  278 2340 rubish.rb
     46  54 546 sed.rb
      95  206 1870 session.rb
     264  708 5906 streamer.rb
 
One nifty thing to do is to collect the outputs of nested commands.

    rbh> ls.map {|f| stat(f).map }
    [["  File: `awk.rb'",
      "  Size: 1013      \tBlocks: 8          IO Block: 4096   regular file",
      "Device: 801h/2049d\tInode: 984369      Links: 1",
      "Access: (0644/-rw-r--r--)  Uid: ( 1000/  howard)   Gid: ( 1000/  howard)",
      "Access: 2009-03-17 21:02:25.000000000 -0700",
      "Modify: 2009-03-17 21:02:13.000000000 -0700",
      "Change: 2009-03-17 21:02:13.000000000 -0700"],
     ["  File: `command_builder.rb'",
      "  Size: 1914      \tBlocks: 8          IO Block: 4096   regular file",
      "Device: 801h/2049d\tInode: 984371      Links: 1",
      "Access: (0644/-rw-r--r--)  Uid: ( 1000/  howard)   Gid: ( 1000/  howard)",
      "Access: 2009-03-17 21:02:25.000000000 -0700",
      "Modify: 2009-03-17 21:02:13.000000000 -0700",
      "Change: 2009-03-17 21:02:13.000000000 -0700"],
    ...
    ]

All the above apply to pipes as well. We can find
out how many files are in a directory as a Ruby
Integer.

    rbh> p { ls; wc}
         23      23     248
    rbh> p { ls; wc}.map
    ["     23      23     248\n"]
    rbh> p { ls; wc}.map.first.split
    ["23", "23", "248"]
    rbh> p { ls; wc}.map.first.split.first.to_i
    23

An big problem with Bash is when you have to
process output with weird characters. Ideally, you
might want to say,

    wc `ls`
   
But that breaks. You have to say,

    find . -maxdepth 1 -print0 | xargs -0 wc
  
And then again, that only works if you are working
with files, and if the command (e.g. wc) accepts
multiple arguments. In Rubish, you can use the
Executable#q method to tell a command to quote its
arguments. Like so,

    wc(ls.map).q
  
# Sed and Awk

Rubish has sedish and awkish things that are not
quite like sed and awk, but not entirely unlike
sed and awk.

`Rubish::Sed` doesn't implicitly print (unlike
real sed). There's actually no option to turn on
implicit printing.

    Rubish::Sed#line
      the current line sed is processing
    Rubish::Sed#p(*args)
      print current line if no argument is given.
    Rubish::Sed#s(regexp,str)
      String#sub! on the current line
    Rubish::Sed#gs(regexp,str)
      String#gsub! on the current line
    Rubish::Sed#q
      quit from sed processing.


    rbh> ls.sed { gs /b/, "bee"; p if line =~ /.rbee$/ }
    awk.rbee
    command_beeuilder.rbee
    command.rbee
    executabeele.rbee
    pipe.rbee
    rubeeish.rbee
    sed.rbee
    session.rbee
    streamer.rbee

    # output to a file
    rbh> ls.sed { p }.o "sed.result"

Rubish::Sed doesn't have the concepts of swapping,
appending, modifying, or any interaction between
pattern space and hold space. Good riddance. The
block is `instance_eval` by the Sed object, so you
can keep track of state using instance variables.

Awk is a lot like sed. But you can associate
actions to be done before or after awk processing.

    Rubish::Awk#begin(&block)
      block is instance_eval by the Awk object
      before processing.
    Rubish::Awk#act(&block)
      blcok is instance_eval by the Awk object for
      each line.
    Rubish::Awk#end(&block)
      block is instance_eval at the end of
      processing. Its value is returned as the
      result.

    rbh> ls.awk { puts do_something(line)}
    # you can have begin and end blocks for awk.
    rbh> ls.awk.begin { ...init }.act { ...body}.end { ...final}
  
You can associate multiple blocks with either awk
or sed. Each block is an "action" that's processed
in left-to-right order.

    rbh> cmd.sed.act { ... }.act { ... }
    rbh> cmd.awk.act { ... }.act { ... }
  
Rubish supports awk/sed-style pattern matching.

    .sed(/a/)  # triggers for lines that matches
    .sed(/a/,/b/) # triggers for lines between (inclusive)
    .sed(1)    # matches line one
    .sed(3,:eof) # matches line 3 to end of stream
    # ditto with awk
    .awk(/a/)


    > cat.i {|p| p.puts((1..10).to_a)}.sed(2,4) { p }
    2
    3
    4

# Streamer

`Rubish::{Sed,Awk}` actually share the
`Rubish::Streamer` mixin. Most of their mechanisms
are implemented by this mixin. It has two
interesting features:

* *Line buffering* allows arbitrary peek ahead (of
lines). This lets you do what sed can with hold
space, but in a much cleaner way.
* *Aggregation* is what awk is all about. But
Rubish::Streamer implements special aggregators
inspired by Common Lisp's Loop facilities.

Let's see line buffering first.

    Rubish::Streamer#peek(n=1)
      Return the next n lines (as Array of Strings),
      and put these lines in the stream buffer.
    Rubish::Streamer#skip(n=1)
      Skip the next n lines.
    Rubish::Streamer#stop(n=1)
      Skip other actions in the streamer, and
      process next line.
    Rubish::Streamer#quit(n=1)
      Quit the streaming process.
    
By the way, isn't it nice that these methods all
have four chars?

    # print files in groups of 3, separated by blank lines.
    rbh> ls.sed { p; puts peek(2); puts ""; skip(3) }
  
In general, the aggregating methods take a name, a
value, and an optional key. The aggregated result
is accumulated in an instance variable named by
the given name. Each aggregator type basically
does foldl on an initial value. The optional key
is used to partition an aggregation.

    Rubish::Streamer#count(name,key=nil)
      count number of times it's called.
    Rubish::Streamer#max(name,val,key=nil)
    Rubish::Streamer#min(name,val,key=nil)
    Rubish::Streamer#sum(name,val,key=nil)
    Rubish::Streamer#collect(name,val,key=nil)
      collect vals into an array.
    Rubish::Streamer#hold(name,size,val,key=nil)
      collect vals into a fixed-size FIFO queue.
    Rubish::Streamer#pick(name,val,key=nil,&block)
      pass the block old_val and new_val, and
      the value returned by block is saved in
      "name".
    
Each aggregator's name is used to create a
bucket. A reader method named by name can be used
to access that bucket. A bucket is a hash of
partitioned accumulation keyed by key. The special
key nil aggregates over the entire domain (like
MySQL's rollup).


    # find the length of the longest file name, and
    # collect the file names.
    ls.awk { f=a[0]; max(:fl,f.length,File.extname(f)); collect(:fn,f)}.end { pp buckets; [fl,fl(""),fn] }
    {:fl=>{""=>10, nil=>18, ".textile"=>14, ".rb"=>18},
     :fn=>
      {nil=>
        ["awk.rb",
         "command_builder.rb",
         "command.rb",
         "executable.rb",
         "LICENSE",
         "ls-result",
         "pipe.rb",
         "README.textile",
         "rubish.rb",
         "sed.rb",
         "sed-result",
         "session.rb",
         "streamer.rb"]}}
    [18,
     10,
     ["awk.rb",
      "command_builder.rb",
      "command.rb",
      "executable.rb",
      "LICENSE",
      "ls-result",
      "pipe.rb",
      "README.textile",
      "rubish.rb",
      "sed.rb",
      "sed-result",
      "session.rb",
      "streamer.rb"]]
  

The first printout of hash is from `pp buckets`.
You can see the aggregation partitioned
by file extensions (in the case of `fl`). Note
that `fl(nil)` holds the max length over all the
files (the entire domain).

# Job Control

All Executable and its subclasses can execute in the background.

    Executable::exec!
      Execute, immediately return a Job
    Executable::each!(&block)
      Iterate the output in the background.
    Executable::map!(acc,&block)
      Accumulate output into a thread-safe
      datastructure with <<
  
A Job has the following methods,

    Job#wait
      Wait for the job to finish. Would block
      the current thread. Raises if computation
      ends abnormally.
    Job#stop
      Signal for the job to terminate, then wait
      for it.

In the case of executing a unix command (or pipe),
`Job#wait` would wait for the child process to
finish. `Job#stop` would send SIGTERM to the
process, then wait.

    # slowcat takes 3 seconds to complete
    > @j = slowcat(3).exec!
    # return immediately
    > @j
    #<Job>
    > @j.wait # blocks for three seconds

Jobs are registered in a JobControl object,

    JobControl#wait(*jobs)
      wait for jobs to complete, then unregister them.
    JobControl#waitall
      wait for all jobs to complete
    JobControl#jobs
      all the registered (and active) jobs.

    > job_control
    #<Rubish::JobControl>
    > wait(@job)
    # == job_control.wait(@job)
    > waitall # == job_control.wait

# Context and Workspace

Rubish gives you fine control over the execution context of Executables.

* Contextual IOs are dynamically scoped.
* Contextual bindings (visible methods) are lexically scoped.

First, contextual IOs

    with {
     cmd1.exec
     cmd2.exec
     with { cmd3.exec }.o("output-3")
    }.o("output-1-and-2")

At the shell, a `Workspace` object contains all
the visible method bindings you can use (as well
as methods from Kernel). Everything else
translates to a `Rubish::Command` instance by
`Workspace#method_missing`. To extend a workspace,
just mix in modules.

However, it's usually not a good idea to include a
module into the Workspace class, since this
extension would be visible in all the Workspace
instances, thus risking incompatibilities among
different extensions. It's better to extend
workspace singletons. The philosophy is, a
workspace is your own. You have the freedom to
mess it up however you like for your personal
conveniences. But the messing-it-up should be
localized.

    Workspace#derive(*modules)
      clone the current workspace, then extend the clone with modules.

Ruby doesn't have lexical scoping for methods, but
you can fake it by creating modules and deriving
workspaces on the fly.

    with(derive({def foo; ...; end})) {
      ... # outer foo
      with(derive({def foo; ...; end})) {
        ... # inner foo
      }
      ... # outer foo
    }

The definition block for `derive` is used by
`Module.new(&block)` to create a dynamic module
that's mixed into a derived Workspace.


# Batch Executable

A batch executable is a block of code executed
within a context in a thread. This gives you
coarse-grained structured concurrency. It's like
subshell, but within the same process, and offers
finer control over IO and namespace (i.e. visible
bindings).

Schematically, a batch job is like,

    @job = Thread.new { context.eval { work }}
    @job.wait

An example,

    @b = batch {
      exec! cmd1, cmd2
      batch {
        exec! cmd3, cmd4
        batch { exec! cmd5 }
      }.exec  
    }
    @b.exec! # => a job

Batches are nestable, such that each batch has its
own job control. A batch finishes when all its
jobs are terminated, as well as the jobs of all
nested job_controls.

Using batches, cocurrent jobs can be organized
structurally into a tree.

A batch is just a wrapper over context, you can
specify the execution context of a batch,

    # extend the batch context
    batch(derive(mod1,mod2)) { ... }

And a batch is an Executable! So all the
Executable methods are applicable:

    batch { ... }.map { |l| ... }
    batch { ... }.tail

# Remote Scripting

It's fun to think about.

Happy Hacking!


# Credit

Created by Howard Yeh.

Gem made available by [Gabriel Horner](http://tagaholic.me/).

