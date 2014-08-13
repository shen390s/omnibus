require 'spec_helper'

module Omnibus
  describe Packager::MSI do
    let(:project) do
      Project.new.tap do |project|
        project.name('project')
        project.homepage('https://example.com')
        project.install_dir('C:/project')
        project.build_version('1.2.3')
        project.build_iteration('2')
        project.maintainer('Chef Software')
      end
    end

    subject { described_class.new(project) }

    let(:project_root) { "#{tmp_path}/project/root" }
    let(:package_dir)  { "#{tmp_path}/package/dir" }
    let(:staging_dir)  { "#{tmp_path}/staging/dir" }

    before do
      Config.project_root(project_root)
      Config.package_dir(package_dir)

      allow(subject).to receive(:staging_dir).and_return(staging_dir)
      create_directory(staging_dir)
    end

    describe 'DSL' do
      it 'exposes :parameters' do
        expect(subject).to have_exposed_method(:parameters)
      end
    end

    describe '#id' do
      it 'is :pkg' do
        expect(subject.id).to eq(:msi)
      end
    end

    describe '#upgrade_code' do
      it 'is a DSL method' do
        expect(subject).to have_exposed_method(:upgrade_code)
      end

      it 'is required' do
        expect {
          subject.upgrade_code
        }.to raise_error(MissingRequiredAttribute)
      end

      it 'requires the value to be a String' do
        expect {
          subject.parameters(Object.new)
        }.to raise_error(InvalidValue)
      end

      it 'returns the given value' do
        code = 'ABCD-1234'
        subject.upgrade_code(code)
        expect(subject.upgrade_code).to be(code)
      end
    end

    describe '#parameters' do
      it 'is a DSL method' do
        expect(subject).to have_exposed_method(:parameters)
      end

      it 'is defaults to an empty hash' do
        expect(subject.parameters).to be_a(Hash)
      end

      it 'requires the value to be a Hash' do
        expect {
          subject.parameters(Object.new)
        }.to raise_error(InvalidValue)
      end

      it 'returns the given value' do
        params = { 'Key' => 'value' }
        subject.parameters(params)
        expect(subject.parameters).to be(params)
      end
    end

    describe '#package_name' do
      it 'includes the name, version, and build iteration' do
        expect(subject.package_name).to eq('project-1.2.3-2.msi')
      end
    end

    describe '#resources_dir' do
      it 'is nested inside the staging_dir' do
        expect(subject.resources_dir).to eq("#{staging_dir}/Resources")
      end
    end

    describe '#write_localization_file' do
      it 'generates the file' do
        subject.write_localization_file
        expect("#{staging_dir}/localization-en-us.wxl").to be_a_file
      end

      it 'has the correct content' do
        subject.write_localization_file
        contents = File.read("#{staging_dir}/localization-en-us.wxl")

        expect(contents).to include('<String Id="ProductName">Project</String>')
        expect(contents).to include('<String Id="ManufacturerName">Chef Software</String>')
        expect(contents).to include('<String Id="FeatureMainName">Project</String>')
      end
    end

    describe '#write_parameters_file' do
      before do
        subject.upgrade_code('ABCD-1234')
      end

      it 'generates the file' do
        subject.write_parameters_file
        expect("#{staging_dir}/parameters.wxi").to be_a_file
      end

      it 'has the correct content' do
        subject.write_parameters_file
        contents = File.read("#{staging_dir}/parameters.wxi")

        expect(contents).to include('<?define VersionNumber="1.2.3.2" ?>')
        expect(contents).to include('<?define DisplayVersionNumber="1.2.3" ?>')
        expect(contents).to include('<?define UpgradeCode="ABCD-1234" ?>')
      end
    end

    describe '#write_source_file' do
      it 'generates the file' do
        subject.write_source_file
        expect("#{staging_dir}/source.wxs").to be_a_file
      end

      it 'has the correct content' do
        subject.write_source_file
        contents = File.read("#{staging_dir}/source.wxs")

        expect(contents).to include('<?include "parameters.wxi" ?>')
        expect(contents).to include('<Directory Id="INSTALLLOCATION" Name="opt">')
        expect(contents).to include('<Directory Id="PROJECTLOCATION" Name="project">')
      end
    end

    describe '#msi_version' do
      context 'when the project build_version semver' do
        it 'returns the right value' do
          expect(subject.msi_version).to eq('1.2.3.2')
        end
      end

      context 'when the project build_version is git' do
        before { project.build_version('1.2.3-alpha.1+20140501194641.git.94.561b564') }

        it 'returns the right value' do
          expect(subject.msi_version).to eq('1.2.3.2')
        end
      end
    end

    describe '#msi_display_version' do
      context 'when the project build_version is "safe"' do
        it 'returns the right value' do
          expect(subject.msi_display_version).to eq('1.2.3')
        end
      end

      context 'when the project build_version is a git tag' do
        before { project.build_version('1.2.3-alpha.1+20140501194641.git.94.561b564') }

        it 'returns the right value' do
          expect(subject.msi_display_version).to eq('1.2.3')
        end
      end
    end
  end
end
