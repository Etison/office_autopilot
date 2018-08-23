require 'spec_helper'

describe OfficeAutopilot::Client do

  before do
    @api_id = 'foo'
    @api_key = 'bar'
    @client = OfficeAutopilot::Client.new(:api_id => @api_id, :api_key => @api_key)
  end

  describe "#new" do
    it "initializes with the given API credentials" do
      expect(@client.api_id).to eq @api_id
      expect(@client.api_key).to eq @api_key
      expect(@client.auth).to eq({ 'Appid' => @api_id, 'Key' => @api_key })
    end

    it "raises an ArgumentError when :api_id is not provided" do
      expect {
        OfficeAutopilot::Client.new(:api_key => 'foo')
      }.to raise_error(ArgumentError)
    end

    it "raises an ArgumentError when :api_key is not provided" do
      expect {
        OfficeAutopilot::Client.new(:api_id => 'foo')
      }.to raise_error(ArgumentError)
    end
  end

  describe "#request" do
    let(:path) { 'path' }
    let(:options) { { body: { key: 'value' } } }
    response = '<result>Success</result>'

    before do
      allow(OfficeAutopilot::Request).to receive(:contact).with(path, options)
        .and_return(response)
    end

    it "makes a HTTP request" do
      expect(@client.request(:contact, path, options)).to eq response
    end
  end

  describe "#handle_response" do
    context "when there are no errors" do
      it "returns the response verbatim" do
        response = '<result>Success</result>'
        expect(@client.handle_response(response)).to eq response
      end
    end

    context "invalid XML error" do
      it "raises OfficeAutopilot::XmlError" do
        expect {
            @client.handle_response( test_data('invalid_xml_error_response.xml') )
        }.to raise_error(OfficeAutopilot::XmlError)
      end
    end
  end

end
