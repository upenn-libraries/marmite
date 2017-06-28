class CreateRecords < ActiveRecord::Migration[5.1]

  def change
    create_table :records do |t|
      t.string :bib_id
      t.string :format
      t.text :blob
    end
  end

end
