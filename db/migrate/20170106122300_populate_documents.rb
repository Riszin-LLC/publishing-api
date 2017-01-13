class PopulateDocuments < ActiveRecord::Migration[5.0]
  def up
    execute "INSERT INTO documents (content_id, locale)
             SELECT content_id, locale FROM content_items
               WHERE document_id IS NULL
                AND (content_id, locale) NOT IN (SELECT content_id, locale FROM documents)
               GROUP BY content_id, locale"
  end
end
