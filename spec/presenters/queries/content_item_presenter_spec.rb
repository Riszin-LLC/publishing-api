require 'rails_helper'

RSpec.describe Presenters::Queries::ContentItemPresenter do
  describe "present" do
    let(:content_id) { SecureRandom.uuid }
    let(:content_item) { FactoryGirl.create(:draft_content_item, content_id: content_id) }
    let!(:version) { FactoryGirl.create(:version, target: content_item, number: 101) }
    let(:result) { Presenters::Queries::ContentItemPresenter.present(content_item) }

    it "presents content item attributes as a hash" do
      expect(result.fetch(:content_id)).to eq(content_id)
    end

    it "exposes the version number of the content item" do
      expect(result.fetch(:version)).to eq(101)
    end

    context "with no published version" do
      it "shows the publication state of the content item as draft" do
        expect(result.fetch(:publication_state)).to eq("draft")
      end

      it "does not include live_version" do
        expect(result).not_to have_key(:live_version)
      end
    end

    context "with a published version and no subsequent draft" do
      let(:live_content_item) { FactoryGirl.create(:live_content_item, content_id: content_id, draft_content_item: content_item) }

      before do
        FactoryGirl.create(:version, target: live_content_item, number: 101)
      end

      it "shows the publication state of the content item as live" do
        expect(result.fetch(:publication_state)).to eq("live")
      end

      it "exposes the live version number" do
        expect(result.fetch(:live_version)).to eq(101)
      end
    end

    context "with a published version and a subsequent draft" do
      let(:live_content_item) { FactoryGirl.create(:live_content_item, content_id: content_id, draft_content_item: content_item) }

      before do
        FactoryGirl.create(:version, target: live_content_item, number: 100)
      end

      it "shows the publication state of the content item as redrafted" do
        expect(result.fetch(:publication_state)).to eq("redrafted")
      end

      it "exposes the live version number" do
        expect(result.fetch(:live_version)).to eq(100)
      end
    end
  end
end
