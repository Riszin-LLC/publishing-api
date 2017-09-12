require "rails_helper"

RSpec.describe "PUT /v2/content when the payload is for a brand new edition" do
  include_context "PutContent call"

  before do
    Timecop.freeze(Time.local(2017, 9, 1, 12, 0, 0))
  end

  after do
    Timecop.return
  end

  let(:public_updated_at) { Time.now }

  subject { Edition.last }

  it "creates an edition" do
    put "/v2/content/#{content_id}", params: payload.to_json

    expect(subject).to be_present
    expect(subject.document.content_id).to eq(content_id)
    expect(subject.title).to eq("Some Title")
  end

  it "sets a draft state for the edition" do
    put "/v2/content/#{content_id}", params: payload.to_json

    expect(subject.state).to eq("draft")
  end

  it "sets a user-facing version of 1 for the edition" do
    put "/v2/content/#{content_id}", params: payload.to_json

    expect(subject.user_facing_version).to eq(1)
  end

  it "creates a lock version for the edition" do
    put "/v2/content/#{content_id}", params: payload.to_json

    expect(subject.document.stale_lock_version).to eq(1)
  end

  it "has a temporary_first_published_at of nil" do
    put "/v2/content/#{content_id}", params: payload.to_json

    expect(subject.temporary_first_published_at).to be_nil
  end

  it "has a major_published_at of nil" do
    put "/v2/content/#{content_id}", params: payload.to_json
    expect(subject.major_published_at).to be_nil
  end

  it "has a publisher_published_at of nil" do
    put "/v2/content/#{content_id}", params: payload.to_json
    expect(subject.publisher_published_at).to be_nil
  end

  it "sets temporary_last_edited_at to current time" do
    put "/v2/content/#{content_id}", params: payload.to_json
    expect(subject.temporary_last_edited_at).to eq(Time.now)
  end

  it "sets last_edited_at to current time" do
    put "/v2/content/#{content_id}", params: payload.to_json
    expect(subject.last_edited_at).to eq(Time.zone.now)
  end

  shared_examples "creates a change note" do
    it "creates a change note" do
      expect {
        put "/v2/content/#{content_id}", params: payload.to_json
      }.to change { ChangeNote.count }.by(1)
    end
  end

  context "first_published_at is present in the payload" do
    let(:first_published_at) { Time.now }
    before do
      payload[:first_published_at] = first_published_at
    end

    it "sets publisher_first_published_at to first_published_at" do
      put "/v2/content/#{content_id}", params: payload.to_json

      expect(subject.publisher_first_published_at).to eq(first_published_at)
    end

    it "sets first_published_at to first_published_at" do
      put "/v2/content/#{content_id}", params: payload.to_json

      expect(subject.first_published_at).to eq(first_published_at)
    end
  end

  context "and the change node is in the payload" do
    include_examples "creates a change note"
  end

  context "and the change history is in the details hash" do
    before do
      payload.delete(:change_note)
      payload[:details] = { change_history: [change_note] }
    end

    include_examples "creates a change note"
  end

  context "and the change note is in the details hash" do
    before do
      payload.delete(:change_note)
      payload[:details] = { change_note: change_note[:note] }
    end

    include_examples "creates a change note"
  end
end
