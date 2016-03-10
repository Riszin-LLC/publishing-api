module Presenters
  module Queries
    class ContentItemPresenter
      attr_accessor :order, :offset, :limit

      def self.present(content_item)
        translation = Translation.find_by!(content_item: content_item)

        content_items = ContentItem.where(content_id: content_item.content_id)
        content_items = Translation.filter(content_items, locale: translation.locale)

        present_many(content_items).first
      end

      def self.present_many(content_item_scope, fields: nil, order: { public_updated_at: :desc }, offset: 0, limit: 50)
        presenter = new(content_item_scope, fields)
        presenter.order = order
        presenter.limit = limit
        presenter.offset = offset
        presenter.present
      end

      def initialize(content_item_scope, fields = nil)
        self.content_item_scope = content_item_scope
        self.fields = fields
      end

      def present
        group_items(groups)
      end

    private

      attr_accessor :content_item_scope, :fields

      def groups
        scope = join_supporting_objects(content_item_scope)
        scope = select_fields(scope).order(order)

        ActiveRecord::Base.connection.execute(aggregated_sql(scope.to_sql))
      end

      def aggregated_sql(sql)
        <<-END.strip_heredoc
          SELECT json_agg(json_rows) FROM (
            SELECT row_to_json(item) json_item FROM (#{sql}) item
          ) json_rows
          GROUP BY json_item->>'content_id', json_item->>'locale'
          ORDER BY max(json_item->>'public_updated_at') DESC
          OFFSET #{offset}
          LIMIT #{limit};
        END
      end

      def group_items(groups)
        groups.map do |raw_group|
          group_items = JSON.parse(raw_group["json_agg"]).map {|g| g["json_item"] }

          draft = detect_draft(group_items)
          live = detect_live(group_items)

          most_recent_item = draft || live
          next unless most_recent_item

          most_recent_item["description"] = most_recent_item["description"]["value"] if most_recent_item["description"]

          if output_fields.include?("internal_name")
            details = most_recent_item.fetch("details")
            most_recent_item["internal_name"] = details["internal_name"] || most_recent_item.fetch("title")
          end

          most_recent_item["publication_state"] = publication_state(draft, live)
          most_recent_item["lock_version"] = most_recent_item.fetch("lock_version").to_i

          if live
            most_recent_item["live_version"] = live.fetch("lock_version").to_i
          end

          most_recent_item.slice(*output_fields)
        end.compact
      end

      def join_supporting_objects(scope)
        scope = State.join_content_items(scope)
        scope = Translation.join_content_items(scope)
        scope = Location.join_content_items(scope)
        scope = UserFacingVersion.join_content_items(scope)
        scope = LockVersion.join_content_items(scope)

        scope
      end

      def select_fields(scope)
        ordering_fields = order.keys.map(&:to_s)
        scope.select(
          *ContentItem::TOP_LEVEL_FIELDS,
          "content_id",
          "states.name as state_name",
          "lock_versions.number as lock_version",
          "translations.locale",
          "locations.base_path",
          *ordering_fields,
        )
      end

      def output_fields
        if fields
          output_fields = fields
        else
          additional_fields = %w(
            locale
            base_path
            lock_version
            publication_state
            live_version
          )

          output_fields = ContentItem::TOP_LEVEL_FIELDS + additional_fields
        end

        output_fields.map(&:to_s)
      end

      def publication_state(draft, live)
        draft_lock_version = draft.fetch("lock_version") if draft
        live_lock_version = live.fetch("lock_version") if live

        if draft_lock_version && live_lock_version && (draft_lock_version > live_lock_version)
          "redrafted"
        elsif live
          "live"
        elsif draft
          "draft"
        else
          raise "Something unexpected happened"
        end
      end

      def detect_draft(items)
        items.detect { |i| i.fetch("state_name") == "draft" }
      end

      def detect_live(items)
        items.detect { |i| i.fetch("state_name") == "published" }
      end
    end
  end
end
