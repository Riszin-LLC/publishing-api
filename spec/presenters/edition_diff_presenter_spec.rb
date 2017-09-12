require 'rails_helper'

RSpec.describe Presenters::EditionDiffPresenter do
  let(:content_id) { SecureRandom.uuid }
  let(:edition) do
    FactoryGirl.create(:edition,
                        update_type: "major",
                        links_hash: { "organisations" => [content_id] },
                        change_note: "a note"
                      )
  end

  let(:edition_without_links) do
    FactoryGirl.create(:edition)
  end

  let(:edition_without_change_note) do
    FactoryGirl.create(:edition,
                        update_type: "minor",
                        links_hash: { "organisations" => [content_id] }
                      )
  end

  EXCLUDED_ATTRIBUTES = %w(updated_at created_at id publishing_request_id document_id).freeze

  describe "#call" do
    subject { described_class }

    context "with links and change_note" do
      it "returns an edition hash presented for diffing" do
        expect(subject.call(edition)).to match a_hash_including(
          edition.as_json.except(*EXCLUDED_ATTRIBUTES).symbolize_keys,
          links: { organisations: [content_id] },
          change_note: edition.change_note.note
        )
      end
    end

    context "without links" do
      it "returns an edition hash presented for diffing" do
        expect(subject.call(edition_without_links)).
          to match a_hash_including(links: {})
      end
    end

    context "without change_note" do
      it "returns an edition hash presented for diffing" do
        expect(subject.call(edition_without_change_note)).
          to match a_hash_including(change_note: {})
      end
    end
  end
end
