require 'spec_helper'

describe OfficeAutopilot::Request do

  describe "HTTParty" do
    it "sets the base uri to the Office Autopilot API host" do
      expect(OfficeAutopilot::Request.base_uri).to eq 'http://api.moon-ray.com'
    end

    it "set the format to :plain" do
      expect(OfficeAutopilot::Request.format).to eq :plain
    end
  end

end
