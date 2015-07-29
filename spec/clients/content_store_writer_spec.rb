require "spec_helper"
require "support/webmock"
require "json"
require "clients/content_store_writer"

RSpec.describe ContentStoreWriter do
  let(:content_store_host) { "http://content-store.example.com" }
  let(:content_store_writer) { ContentStoreWriter.new(content_store_host) }
  let(:base_path) { "/test/item" }

  let(:content_item) {
    {
      base_path: base_path,
      details: {
        etc: ["one", "two", "three"]
      },
    }
  }

  let(:publish_intent) {
    {
      publish_time: Time.now.iso8601,
      publishing_app: "whitehall",
      rendering_app: "whitehall-frontend",
      routes: [
        {
          path: base_path,
          type: "exact",
        }
      ]
    }
  }

  describe "#put_content_item" do
    it "writes the content item as JSON to the given content store" do
      put_request = stub_request(:put, "#{content_store_host}/content#{base_path}")
        .with(body: content_item.to_json)

      content_store_writer.put_content_item(content_item)

      expect(put_request).to have_been_requested
    end
  end

  describe "#put_publish_intent" do
    it "writes the publish intent as JSON to the given content store" do
      put_request = stub_request(:put, "#{content_store_host}/publish-intent#{base_path}")
        .with(body: publish_intent.to_json)

      content_store_writer.put_publish_intent(
        base_path: base_path,
        publish_intent: publish_intent
      )

      expect(put_request).to have_been_requested
    end
  end
end
