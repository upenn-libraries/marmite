class CreateRecords < ActiveRecord::Migration[5.1]

  def change
    create_table :records do |t|
      t.string :bib_id
      t.string :format
      t.text :blob, :limit => 4294967295
    end
  end

end
