module Presenters
  module Queries
    class ContentItemPresenter
      def self.present(content_item)
        version = Version.find_by(target: content_item)
        live_version = Version.find_by(target: content_item.live_content_item)
        new(content_item, version, live_version).present
      end

      def initialize(content_item, version, live_version)
        self.content_item = content_item
        self.version = version
        self.live_version = live_version
      end

      def present
        content_item.as_json
          .symbolize_keys
          .merge(
            version: version.number,
            publication_state: publication_state,
          ).tap { |h| h[:live_version] = live_version.number if live_version.present? }
      end

    private

      attr_accessor :content_item, :version, :live_version

      def publication_state
        if live_version.nil?
          'draft'
        else
          version.number > live_version.number ? 'redrafted' : 'live'
        end
      end
    end
  end
end
