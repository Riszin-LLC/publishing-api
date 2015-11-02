class LiveContentItem < ActiveRecord::Base
  include Replaceable
  include DefaultAttributes
  include SymbolizeJSON
  include ImmutableBasePath

  TOP_LEVEL_FIELDS = [
    :base_path,
    :content_id,
    :description,
    :details,
    :format,
    :locale,
    :public_updated_at,
    :publishing_app,
    :redirects,
    :rendering_app,
    :routes,
    :title,
  ].freeze

  NON_RENDERABLE_FORMATS = %w(redirect gone)

  belongs_to :draft_content_item

  scope :renderable_content, -> { where.not(format: NON_RENDERABLE_FORMATS) }

  validates :draft_content_item, presence: true
  validates :content_id, presence: true, uuid: true
  validate :content_ids_match
  validates :base_path, absolute_path: true
  validates :format, presence: true
  validates :publishing_app, presence: true
  validates :title, presence: true, if: :renderable_content?
  validates :rendering_app, presence: true, dns_hostname: true, if: :renderable_content?

private
  def self.query_keys
    [:content_id, :locale]
  end

  def content_ids_match
    if draft_content_item && draft_content_item.content_id != content_id
      errors.add(:content_id, "id mismatch between draft and live content items")
    end
  end

  def renderable_content?
    NON_RENDERABLE_FORMATS.exclude?(format)
  end
end
