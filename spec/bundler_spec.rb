require "spec_helper"

describe "jetpack - bundler and gems" do
  let(:project) { "#{TEST_ROOT}/has_gems_via_bundler" }
  let(:dest) { "#{TEST_ROOT}/has_gems_via_bundler_dest" }
  
  before(:all) do
    reset
    FileUtils.cp_r("spec/sample_projects/has_gems_via_bundler", "#{TEST_ROOT}/has_gems_via_bundler")
    x!("bin/jetpack-bootstrap #{project} base")
    @result = x!("bin/jetpack #{project} #{dest}")
  end
  after(:all) do
    reset
  end

  describe "presence of the library" do
    it "installed bundler into vendor/bundler_gem." do
      files = Dir["#{dest}/vendor/bundler_gem/**/*.rb"].to_a.map{|f|File.basename(f)}
      files.should include("bundler.rb")
      files.should include("dsl.rb")
    end

    it "is not accidentally using bundler from another ruby environment." do
      rake_result = x("#{dest}/bin/rake load_path_with_bundler")
      load_path_elements = rake_result[:stdout].split("\n").select{|line|line =~ /^--/}
      load_path_elements.length.should >= 3
      invalid_load_path_elements =
        load_path_elements.reject do |element|
          element = element.sub("-- ", "")
          (element =~ /META-INF\/jruby\.home/ || element =~ /vendor\/bundler_gem/ || element =~ /^\.$/ || element =~ /vendor\/bundle\//)
        end
      invalid_load_path_elements.should == []
    end

    it "can be used from a script fed to jruby." do
      rake_result = x(%{#{dest}/bin/ruby -e 'require \\"rubygems\\"; require \\"bundler\\"; puts Bundler::VERSION'})
      rake_result[:stderr].should     == ""
      rake_result[:stdout].should include("1.1.0")
      rake_result[:exitstatus].should == 0
    end
  end

  describe "gem installation" do
    it "installs gems into vendor/bundle" do
      files = Dir["#{dest}/vendor/bundle/**/*.rb"].to_a.map{|f|File.basename(f)}
      files.should include("bijection.rb")
      files.should include("spruz.rb")
      files.length.should > 20
    end

    it "installed gems are available via normal require" do
      rake_result = x("cd #{dest} && " +
                      %{bin/ruby -e 'require \\"rubygems\\"; require \\"bundler/setup\\"; require \\"spruz/bijection\\"; puts Spruz::Bijection.name'})
      rake_result[:stderr].should     == ""
      rake_result[:stdout].should     == "Spruz::Bijection\n"
      rake_result[:exitstatus].should == 0
    end

    it "installed gems are available via Bundler.require" do
      rake_result = x("cd #{dest} && " +
                      %{bin/ruby -e 'require \\"rubygems\\"; require \\"bundler\\"; Bundler.require; puts Spruz::Bijection.name'})
      rake_result[:stderr].should     == ""
      rake_result[:stdout].should     == "Spruz::Bijection\n"
      rake_result[:exitstatus].should == 0
    end
  end

  describe "bin/rake" do
    it "uses rake version specified in Gemfile" do
      rake_result = x("#{dest}/bin/rake rake_version")
      rake_result[:stdout].lines.to_a.last.chomp.should == "0.9.2.2"
    end
  end

  describe "Gemfile.lock that does not contain PLATFORM=java" do
    before do
      File.open("spec/sample_projects/has_gems_via_bundler_bad_gemfile_lock/Gemfile.lock", "w") do |f|
        f << %{GEM
  remote: http://rubygems.org/
  specs:
    rake (0.9.2.2)
    spruz (0.2.13)

PLATFORMS
  ruby

DEPENDENCIES
  rake (~> 0.9.2)
  spruz
}
      end
    end

    after do
      FileUtils.rm_f("spec/sample_projects/has_gems_via_bundler_bad_gemfile_lock/Gemfile.lock")
      reset
    end

    it "regenerates the Gemfile.lock and prints out a warning message" do
      File.read("spec/sample_projects/has_gems_via_bundler_bad_gemfile_lock/Gemfile.lock").should_not include("java")
      FileUtils.cp_r("spec/sample_projects/has_gems_via_bundler_bad_gemfile_lock",
                     "#{TEST_ROOT}/has_gems_via_bundler_bad_gemfile_lock")
      x!("bin/jetpack-bootstrap #{TEST_ROOT}/has_gems_via_bundler_bad_gemfile_lock base")
      jetpack_result = x("bin/jetpack #{TEST_ROOT}/has_gems_via_bundler_bad_gemfile_lock #{TEST_ROOT}/has_gems_via_bundler_bad_gemfile_lock_dest")
      jetpack_result[:stderr].gsub("\n", "").squeeze(" ").should include(%{
        WARNING: Your Gemfile.lock does not contain PLATFORM java.
        Automtically regenerating and overwriting Gemfile.lock using jruby
         - because otherwise, jruby-specific gems would not be installed by bundler.
        To make this message go away, you must re-generate your Gemfile.lock using jruby.
      }.gsub("\n", "").squeeze(" "))
      jetpack_result[:exitstatus].should == 0

      File.read("#{TEST_ROOT}/has_gems_via_bundler_bad_gemfile_lock_dest/Gemfile.lock").should include("java")

      rake_result = x("cd #{TEST_ROOT}/has_gems_via_bundler_bad_gemfile_lock_dest && " +
                      %{bin/ruby -e 'require \\"rubygems\\"; require \\"bundler\\"; Bundler.require; puts Spruz::Bijection.name'})
      rake_result[:stderr].should     == ""
      rake_result[:stdout].should     == "Spruz::Bijection\n"
      rake_result[:exitstatus].should == 0
    end
  end

end
