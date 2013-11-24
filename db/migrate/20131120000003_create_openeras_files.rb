class CreateOpenerasFiles < ActiveRecord::Migration
  def change
    create_table :openeras_files do |t|

      t.attachment  :file
      t.string      :name
      t.string      :description
      t.string      :copyright
      t.integer     :position, default: 0

      t.belongs_to  :project
      t.belongs_to  :venue
      t.belongs_to  :person

      t.integer     :updated_by
      t.integer     :created_by

      t.timestamps

    end
  end
end
