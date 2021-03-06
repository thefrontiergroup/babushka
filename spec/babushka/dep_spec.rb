require 'spec_helper'
require 'dep_support'

describe "Dep.make" do
  it "should reject deps with empty names" do
    L{
      Dep.make "", Base.sources.anonymous, {}, nil
    }.should raise_error(DepError, "Deps can't have empty names.")
    Dep("carriage\rreturn").should be_nil
  end
  it "should reject deps with nonprintable characters in their names" do
    L{
      Dep.make "carriage\rreturn", Base.sources.anonymous, {}, nil
    }.should raise_error(DepError, "The dep name 'carriage\rreturn' contains nonprintable characters.")
    Dep("carriage\rreturn").should be_nil
  end
  it "should reject deps slashes in their names" do
    L{
      Dep.make "slashes/invalidate names", Base.sources.anonymous, {}, nil
    }.should raise_error(DepError, "The dep name 'slashes/invalidate names' contains '/', which isn't allowed (logs are named after deps, and filenames can't contain '/').")
    Dep("slashes/invalidate names").should be_nil
  end
  it "should reject deps colons in their names" do
    L{
      Dep.make "colons:invalidate names", Base.sources.anonymous, {}, nil
    }.should raise_error(DepError, "The dep name 'colons:invalidate names' contains ':', which isn't allowed (colons separate dep and template names from source prefixes).")
    Dep("colons:invalidate names").should be_nil
  end
  it "should create deps with valid names" do
    L{
      Dep.make("valid dep name", Base.sources.anonymous, {}, nil).should be_an_instance_of(Dep)
    }.should change(Base.sources.anonymous, :count).by(1)
    Dep("valid dep name").should be_an_instance_of(Dep)
  end
  context "without template" do
    before {
      @dep = Dep.make("valid base dep", Base.sources.anonymous, {}, nil)
    }
    it "should work" do
      @dep.should be_an_instance_of(Dep)
      @dep.template.should == Dep::BaseTemplate
    end
  end
  context "with template" do
    it "should fail to create optioned deps against a missing template" do
      L{
        Dep.make("valid but missing template", Base.sources.anonymous, {:template => 'template'}, nil)
      }.should raise_error(DepError, "There is no template named 'template' to define 'valid but missing template' against.")
    end
    context "with template from options" do
      before {
        @meta = meta('option template')
        @dep = Dep.make("valid option dep", Base.sources.anonymous, {:template => 'option template'}, nil)
      }
      it "should work" do
        @dep.should be_an_instance_of(Dep)
        @dep.template.should == @meta
      end
    end
    context "with template from suffix" do
      before {
        @meta = meta('.suffix_template')
        @dep = Dep.make("valid dep name.suffix_template", Base.sources.anonymous, {}, nil)
      }
      it "should work" do
        @dep.should be_an_instance_of(Dep)
        @dep.template.should == @meta
      end
    end
    after { Base.sources.anonymous.templates.clear! }
  end
end

describe Dep, '.find_or_suggest' do
  before {
    @dep = dep 'Dep.find_or_suggest tests'
  }
  it "should find the given dep and yield the block" do
    Dep.find_or_suggest('Dep.find_or_suggest tests') {|dep| dep }.should == @dep
  end
  context "namespaced" do
    before {
      @source = Source.new(nil, :name => 'namespaced')
      Source.stub!(:present).and_return([@source])
      Base.sources.load_context :source => @source do
        @namespaced_dep = dep 'namespaced Dep.find_or_suggest tests'
      end
    }
    it "should not find the dep without a namespace" do
      Dep.find_or_suggest('namespaced Dep.find_or_suggest tests').should be_nil
    end
    it "should not find the dep with an incorrect namespace" do
      Dep.find_or_suggest('incorrect:namespaced Dep.find_or_suggest tests').should be_nil
    end
    it "should find the dep with the correct namespace" do
      Dep.find_or_suggest('namespaced:namespaced Dep.find_or_suggest tests').should == @namespaced_dep
    end
    it "should find the dep with the correct namespace and yield it to the block" do
      Dep.find_or_suggest('namespaced:namespaced Dep.find_or_suggest tests') {|dep| dep }.should == @namespaced_dep
    end
  end
  context "from other deps" do
    before {
      @source = Source.new(nil, :name => 'namespaced')
      Source.stub!(:present).and_return([@source])
      Base.sources.load_context :source => @source do
        @namespaced_dep = dep 'namespaced Dep.find_or_suggest tests' do
          requires 'Dep.find_or_suggest sub-dep'
        end
      end
    }
    context "without namespacing" do
      before {
        @sub_dep = dep 'Dep.find_or_suggest sub-dep'
      }
      it "should find the sub dep" do
        @sub_dep.should_receive :process
        @namespaced_dep.process
      end
    end
    context "in the same namespace" do
      before {
        Base.sources.load_context :source => @source do
          @sub_dep = dep 'Dep.find_or_suggest sub-dep'
        end
      }
      it "should find the sub dep" do
        @sub_dep.should_receive :process
        @namespaced_dep.process
      end
    end
    context "in a different namespace" do
      before {
        @source = Source.new(nil, :name => 'namespaced')
        @source2 = Source.new(nil, :name => 'another namespaced')
        Source.stub!(:present).and_return([@source, @source2])
        Base.sources.load_context :source => @source do
          @namespaced_dep = dep 'namespaced Dep.find_or_suggest tests' do
            requires 'Dep.find_or_suggest sub-dep'
          end
        end
        Base.sources.load_context :source => @source2 do
          @sub_dep = dep 'Dep.find_or_suggest sub-dep'
        end
      }
      it "should not find the sub dep" do
        @sub_dep.should_not_receive :process
        @namespaced_dep.process
      end
    end
  end
end

describe "dep creation" do
  it "should work for blank deps" do
    L{
      dep "blank"
    }.should change(Base.sources.anonymous, :count).by(1)
    Dep('blank').should be_an_instance_of(Dep)
  end
  it "should work for filled in deps" do
    L{
      dep "standard" do
        requires 'blank'
        before { }
        met? { }
        meet { }
        after { }
      end
    }.should change(Base.sources.anonymous, :count).by(1)
    Dep('standard').should be_an_instance_of(Dep)
  end
  it "should accept deps as dep names" do
    L{
      dep 'parent dep' do
        requires dep('nested dep')
      end
    }.should change(Base.sources.anonymous, :count).by(2)
    Dep('parent dep').context.requires.should == [Dep('nested dep')]
  end
  after { Base.sources.anonymous.deps.clear! }

  context "without template" do
    before { dep 'without template' }
    it "should use the base template" do
      Dep('without template').template.should == Dep::BaseTemplate
    end
  end
  context "with option template" do
    before {
      @template = meta 'option template'
    }
    it "should use the specified template as an option" do
      dep('with option template', :template => 'option template').template.should == @template
    end
    it "should not recognise the template as a suffix" do
      dep('with option template.option template').template.should == Dep::BaseTemplate
    end
  end
  context "with suffix template" do
    before {
      @template = meta '.suffix_template'
    }
    context "as option template" do
      before {
        @dep = dep('with suffix template', :template => 'suffix_template')
      }
      it "should use the specified template as an option" do
        @dep.template.should == @template
      end
      it "should not be suffixed" do
        @dep.should_not be_suffixed
        @dep.suffix.should be_nil
      end
    end
    context "as suffix template" do
      before {
        @dep = dep('with suffix template.suffix_template')
      }
      it "should use the specified template as a suffix" do
        @dep.template.should == @template
      end
      it "should not be suffixed" do
        @dep.should be_suffixed
        @dep.suffix.should == 'suffix_template'
      end
    end
  end
  context "with both templates" do
    before {
      meta '.suffix_template'
      @template = meta 'option template'
    }
    it "should use the option template" do
      dep('with both templates.suffix_template', :template => 'option template').template.should == @template
    end
  end
  after { Base.sources.anonymous.templates.clear! }
end

describe Dep, "defining" do
  it "should define the dep when called without a block" do
    dep('defining test').dep_defined?.should == true
  end
  it "should define the dep when called with a block" do
    dep('defining test with block') do
      requires 'another dep'
    end.dep_defined?.should == true
  end
  context "lazily" do
    it "should not define the dep when called without a block" do
      dep('lazy defining test', :lazy => true).dep_defined?.should == nil
    end
    it "should not define the dep when called with a block" do
      dep('lazy defining test with block', :lazy => true) do
        requires 'another dep'
      end.dep_defined?.should == nil
    end
    context "after running" do
      it "should be defined" do
        dep('lazy defining test with run', :lazy => true).tap {|dep|
          dep.met?
        }.dep_defined?.should == true
      end
      context "with a template" do
        let!(:template) { meta 'lazy_defining_template' }
        it "should use the template" do
          dep('lazy defining test with template.lazy_defining_template', :lazy => true).tap {|dep|
            dep.met?
            dep.template.should == template
          }
        end
      end
    end
  end
  context "after errors" do
    it "should not be defined, returning false to represent load errors" do
      dep('defining test with errors') do
        nonexistent_method
      end.dep_defined?.should == false
    end
    context "lazily" do
      it "should not be defined, and then have failed defining after a run" do
        dep('lazy defining test with errors', :lazy => true) do
          nonexistent_method
        end.tap {|dep|
          dep.dep_defined?.should == nil
          dep.met?
        }.dep_defined?.should == false
      end
    end
  end
  context "repeatedly" do
    it "should only ever define the dep once" do
      dep('defining test with repetition').tap {|dep|
        dep.context.should_receive(:define!).never
        dep.met?
      }
    end
    it "should not overwrite custom blocks" do
      dep('defining test with block overwriting') do
        setup { true }
      end.tap {|dep|
        dep.define!
        dep.context.setup { 'custom' }
        dep.define!
        dep.send(:process_task, :setup).should == 'custom'
      }
    end
    context "lazily" do
      it "should only ever define the dep once" do
        dep('lazy defining test with repetition', :lazy => true).tap {|dep|
          dep.met?
          dep.context.should_receive(:define!).never
          dep.met?
        }
      end
      it "should not overwrite custom blocks" do
        dep('lazy defining test with block overwriting', :lazy => true) do
          setup { true }
        end.tap {|dep|
          dep.define!
          dep.context.setup { 'custom' }
          dep.define!
          dep.send(:process_task, :setup).should == 'custom'
        }
      end
    end
  end
end

describe Dep, '#basename' do
  context "for base deps" do
    it "should be the same as the dep's name" do
      dep('basename test').basename.should == 'basename test'
    end
    context "with a suffix" do
      it "should be the same as the dep's name" do
        dep('basename test.basename_test').basename.should == 'basename test.basename_test'
      end
    end
  end
  context "for option-templated deps" do
    before { meta 'basename template' }
    it "should be the same as the dep's name" do
      dep('basename test', :template => 'basename template').basename.should == 'basename test'
    end
    context "with a suffix" do
      it "should be the same as the dep's name" do
        dep('basename test.basename template', :template => 'basename template').basename.should == 'basename test.basename template'
      end
    end
    after { Base.sources.anonymous.templates.clear! }
  end
  context "for suffix-templated deps" do
    before { meta 'basename_template' }
    it "should remove the suffix name" do
      dep('basename test.basename_template').basename.should == 'basename test'
    end
    after { Base.sources.anonymous.templates.clear! }
  end
end

describe Dep, 'lambda lists' do
  before {
    Babushka::Base.host.stub!(:name).and_return(:test_name)
    Babushka::Base.host.stub!(:system).and_return(:test_system)
    Babushka::Base.host.stub!(:pkg_helper_key).and_return(:test_helper)

    Babushka::Base.host.stub!(:all_names).and_return([:test_name, :other_name])
    Babushka::Base.host.stub!(:all_systems).and_return([:test_system, :other_system])
    Babushka::PkgHelper.stub!(:all_manager_keys).and_return([:test_helper, :other_helper])
  }
  it "should match against the system name" do
    dep('lambda list name match') { requires { on :test_name, 'awesome' } }.context.requires.should == ['awesome']
  end
  it "should match against the system type" do
    dep('lambda list system match') { requires { on :test_system, 'awesome' } }.context.requires.should == ['awesome']
  end
  it "should match against the system name" do
    dep('lambda list pkg_helper_key match') { requires { on :test_helper, 'awesome' } }.context.requires.should == ['awesome']
  end
end

describe "calling met? on a single dep" do
  before {
    setup_yield_counts
  }
  it "should run if setup returns nil or false" do
    make_counter_dep(
      :name => 'unmeetable for met', :setup => L{ false }, :met? => L{ false }
    ).met?.should == false
    @yield_counts['unmeetable for met'].should == @yield_counts_met_run
  end
  it "should return false for unmet deps" do
    make_counter_dep(
      :name => 'unmeetable for met', :met? => L{ false }
    ).met?.should == false
    @yield_counts['unmeetable for met'].should == @yield_counts_met_run
  end
  it "should return true for already met deps" do
    make_counter_dep(
      :name => 'met for met'
    ).met?.should == true
    @yield_counts['met for met'].should == @yield_counts_met_run
  end
  after { Base.sources.anonymous.deps.clear! }
end

describe "exceptions" do
  it "should be unmet after an exception in met? {}" do
    dep 'exception met? test' do
      met? { raise }
    end.met?.should be_false
  end
  it "should be unmet after an exception in meet {}" do
    dep 'exception meet test' do
      met? { false }
      meet { raise }
    end.met?.should be_false
  end
end

describe "calling meet on a single dep" do
  before {
    setup_yield_counts
  }
  it "should fail twice and return false on unmeetable deps" do
    make_counter_dep(
      :name => 'unmeetable', :met? => L{ false }
    ).meet.should == false
    @yield_counts['unmeetable'].should == @yield_counts_meet_run
  end
  it "should fail fast and return nil on explicitly unmeetable deps" do
    make_counter_dep(
      :name => 'explicitly unmeetable', :met? => L{ raise UnmeetableDep }
    ).meet.should == nil
    @yield_counts['explicitly unmeetable'].should == @yield_counts_met_run
  end
  it "should fail, run meet, and then succeed on unmet deps" do
    make_counter_dep(
      :name => 'unmet', :met? => L{ @yield_counts['unmet'][:met?] > 1 }
    ).meet.should == true
    @yield_counts['unmet'].should == @yield_counts_meet_run
  end
  it "should fail, not run meet, and fail again on unmet deps where before fails" do
    make_counter_dep(
      :name => 'unmet, #before fails', :met? => L{ false }, :before => L{ false }
    ).meet.should == false
    @yield_counts['unmet, #before fails'].should == @yield_counts_failed_at_before
  end
  it "should fail, not run meet, and fail again on unmet deps where meet raises UnmeetableDep" do
    make_counter_dep(
      :name => 'unmet, #before fails', :met? => L{ false }, :meet => L{ raise UnmeetableDep }
    ).meet.should == nil
    @yield_counts['unmet, #before fails'].should == @yield_counts_early_exit_meet_run
  end
  it "should fail, run meet, and then succeed on unmet deps where after fails" do
    make_counter_dep(
      :name => 'unmet, #after fails', :met? => L{ @yield_counts['unmet, #after fails'][:met?] > 1 }, :after => L{ false }
    ).meet.should == true
    @yield_counts['unmet, #after fails'].should == @yield_counts_meet_run
  end
  it "should succeed on already met deps" do
    make_counter_dep(
      :name => 'met', :met? => L{ true }
    ).meet.should == true
    @yield_counts['met'].should == @yield_counts_already_met
  end
  after { Base.sources.anonymous.deps.clear! }
end

describe "run_in" do
  it "should run in the current directory when run_in isn't set" do
    cwd = Dir.pwd
    ran_in = nil
    dep 'dep without run_in set' do
      met? { ran_in = Dir.pwd }
    end.met?
    Dir.pwd.should == cwd
    ran_in.should == cwd
  end
  it "should fail when run_in is set to a nonexistent directory" do
    L{
      dep 'dep with run_in set to a nonexistent dir' do
        run_in((tmp_prefix / 'nonexistent').to_s)
      end.met?
    }.should raise_error(Errno::ENOENT, "No such file or directory - #{tmp_prefix / 'nonexistent'}")
  end
  it "should run in the specified directory when run_in is set" do
    cwd = Dir.pwd
    ran_in = nil
    dep 'dep with run_in set' do
      run_in tmp_prefix
      met? { ran_in = Dir.pwd }
    end.met?
    Dir.pwd.should == cwd
    ran_in.should == tmp_prefix
  end
  it "should run this deps' requirements in the original directory" do
    cwd = Dir.pwd
    ran_in = child_ran_in = nil
    dep 'another without run_in set' do
      met? { child_ran_in = Dir.pwd }
    end
    dep 'dep with run_in set' do
      requires 'another without run_in set'
      run_in tmp_prefix
      met? { ran_in = Dir.pwd }
    end.met?
    Dir.pwd.should == cwd
    ran_in.should == tmp_prefix
    child_ran_in.should == cwd
  end
  it "should run this deps' requirements in their own directories when specified" do
    cwd = Dir.pwd
    ran_in = child_ran_in = nil
    (tmp_prefix / 'run_in').mkdir
    dep 'another with run_in set' do
      run_in tmp_prefix / 'run_in'
      met? { child_ran_in = Dir.pwd }
    end
    dep 'dep with run_in set' do
      requires 'another with run_in set'
      run_in tmp_prefix
      met? { ran_in = Dir.pwd }
    end.met?
    Dir.pwd.should == cwd
    ran_in.should == tmp_prefix
    child_ran_in.should == tmp_prefix / 'run_in'
  end
  after { Base.sources.anonymous.deps.clear! }
end
