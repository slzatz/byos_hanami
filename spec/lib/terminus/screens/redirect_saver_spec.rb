# frozen_string_literal: true

require "hanami_helper"

RSpec.describe Terminus::Screens::RedirectSaver do
  describe "#call" do
    subject(:saver) { described_class.new }

    let(:remote_uri) { "https://example.com/image.png" }
    let(:output_path) { Pathname("/tmp/test.png") }
    let(:redirect_path) { Pathname("/tmp/test.redirect") }

    before do
      allow(File).to receive(:write)
    end

    context "when saving succeeds" do
      it "creates a redirect file with the remote URI" do
        result = saver.call(remote_uri, output_path)
        
        expect(File).to have_received(:write).with(redirect_path, remote_uri)
        expect(result).to be_success
        expect(result.success).to eq(redirect_path.to_s)
      end
    end

    context "when saving fails" do
      before do
        allow(File).to receive(:write).and_raise(StandardError, "File write error")
      end

      it "returns a failure with error message" do
        result = saver.call(remote_uri, output_path)
        
        expect(result).to be_failure
        expect(result.failure).to eq("File write error")
      end
    end
  end
end