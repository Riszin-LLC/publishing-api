require "rails_helper"

RSpec.describe "PUT /v2/content when creating a draft for a previously published edition" do
  include_context "PutContent call"

  before do
    stub_request(:put, %r{.*content-store.*/content/.*})
    Timecop.freeze(Time.local(2017, 9, 1, 12, 0, 0))
  end

  after do
    Timecop.return
  end

  let(:first_published_at) { 1.year.ago }
  let(:temporary_first_published_at) { 2.years.ago }
  let(:major_published_at) { 1.year.ago }

  let(:document) do
    FactoryGirl.create(
      :document,
      content_id: content_id,
      stale_lock_version: 5,
    )
  end

  let!(:edition) do
    FactoryGirl.create(:live_edition,
      document: document,
      user_facing_version: 5,
      first_published_at: first_published_at,
      temporary_first_published_at: temporary_first_published_at,
      base_path: base_path,
      major_published_at: major_published_at,
    )
  end

  let!(:link) do
    edition.links.create(link_type: "test",
                         target_content_id: document.content_id)
  end

  it "creates the draft's user-facing version using the live's user-facing version as a starting point" do
    put "/v2/content/#{content_id}", params: payload.to_json

    edition = Edition.last

    expect(edition).to be_present
    expect(edition.document.content_id).to eq(content_id)
    expect(edition.state).to eq("draft")
    expect(edition.user_facing_version).to eq(6)
  end

  it "copies over the first_published_at timestamp" do
    put "/v2/content/#{content_id}", params: payload.to_json

    edition = Edition.last
    expect(edition).to be_present
    expect(edition.document.content_id).to eq(content_id)

    expect(edition.first_published_at.iso8601).to eq(first_published_at.iso8601)
  end

  it "sets temporary_first_published_at to the previously published version's value" do
    put "/v2/content/#{content_id}", params: payload.to_json

    edition = Edition.last
    expect(edition.temporary_first_published_at)
      .to eq(temporary_first_published_at)
  end

  context "when update_type is minor" do
    before do
      payload[:update_type] = "minor"
    end

    it "sets major_published_at to previous published edition's value" do
      put "/v2/content/#{content_id}", params: payload.to_json

      edition = Edition.last
      expect(edition.major_published_at.iso8601)
        .to eq(major_published_at.iso8601)
    end
  end

  context "when first_published_at has changed in the payload" do
    let(:new_first_published_at) { Time.now.utc.iso8601 }
    before do
      payload.merge!(first_published_at: new_first_published_at)
    end

    it "updates publisher_first_published_at" do
      put "/v2/content/#{content_id}", params: payload.to_json

      edition = Edition.last
      expect(edition.publisher_first_published_at.iso8601)
        .to eq(new_first_published_at)
    end
  end

  context "and public_updated_at has changed in the payload" do
    let(:public_updated_at) { Time.now.utc }
    before do
      payload.merge!(
        public_updated_at: public_updated_at,
        update_type: "major"
      )
    end

    it "updates publisher_major_published_at" do
      put "/v2/content/#{content_id}", params: payload.to_json

      edition = Edition.last
      expect(edition.publisher_major_published_at).to eq(public_updated_at)
    end
  end

  context "and the base path has changed" do
    before do
      payload.merge!(
        base_path: "/moved",
        routes: [{ path: "/moved", type: "exact" }],
      )
    end

    it "sets the correct base path on the location" do
      put "/v2/content/#{content_id}", params: payload.to_json

      expect(Edition.where(base_path: "/moved", state: "draft")).to exist
    end

    it "creates a redirect" do
      put "/v2/content/#{content_id}", params: payload.to_json

      redirect = Edition.find_by(
        base_path: base_path,
        state: "draft",
      )

      expect(redirect).to be_present
      expect(redirect.schema_name).to eq("redirect")
      expect(redirect.publishing_app).to eq("publisher")

      expect(redirect.redirects).to eq([{
        path: base_path,
        type: "exact",
        destination: "/moved",
      }])

      expect(redirect.document.owning_document).to eq(edition.document)
    end

    it "sends a create request to the draft content store for the redirect" do
      expect(DownstreamDraftWorker).to receive(:perform_async_in_queue).twice

      put "/v2/content/#{content_id}", params: payload.to_json
    end

    context "when the locale differs from the existing draft edition" do
      before do
        payload.merge!(locale: "fr", title: "French Title")
      end

      it "creates a separate draft edition in the given locale" do
        put "/v2/content/#{content_id}", params: payload.to_json
        expect(Edition.count).to eq(2)

        edition = Edition.last
        expect(edition.title).to eq("French Title")
        expect(edition.document.locale).to eq("fr")
      end
    end
  end
end
