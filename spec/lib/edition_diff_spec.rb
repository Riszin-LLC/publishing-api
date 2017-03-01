require 'rails_helper'

RSpec.describe EditionDiff do
  let(:content_id) { SecureRandom.uuid }
  let(:document) { FactoryGirl.create(:document, content_id: content_id) }

  let!(:previous_edition) do
    FactoryGirl.create(:superseded_edition, document: document,
                       title: "Foo", base_path: "/foo")
  end

  let!(:current_edition) do
    FactoryGirl.create(:live_edition, document: document,
                       title: "Bar", base_path: "/foo",
                       user_facing_version: 2)
  end

  let(:new_draft_edition) do
    FactoryGirl.create(:draft_edition, document: document,
                       title: "Bar", base_path: "/foo",
                       user_facing_version: 3)
  end

  subject { described_class.new(current_edition) }

  context "diff in title" do
    it "returns the diff between two versions" do
      expect(subject.field_diff).to eq([:title])
    end
  end

  context "diff in title, document_type and base_path" do
    let!(:current_edition) do
      FactoryGirl.create(
        :live_edition,
        document: document,
        title: "Bar",
        base_path: "/bar",
        user_facing_version: 2,
        document_type: "new_type"
      )
    end

    it "returns the diff between two versions" do
      expect(subject.field_diff).to include(:base_path, :title, :document_type)
    end
  end

  context "multiple versions" do
    it "compares between the previous version" do
      current_edition.supersede
      expect(described_class.new(new_draft_edition).field_diff).to eq([])
    end
  end

  context "no previous item" do
    let!(:previous_edition) { nil }
    it "returns the diff between two versions" do
      expect(subject.field_diff).to include(:base_path, :title, :document_type)
    end
  end

  context "provide the edition to compare" do
    it "compares the two given editions" do
      expect(
        EditionDiff.new(new_draft_edition,
                        previous_edition: {}).field_diff
      ).to include(:document_type, :title)
    end

    let(:presented_item) do
      Presenters::EditionPresenter.new(new_draft_edition).present.deep_stringify_keys
    end

    it "compares the two given editions" do
      expect(
        EditionDiff.new(new_draft_edition,
                        previous_edition: presented_item).field_diff
      ).to eq([])
    end
  end
end
