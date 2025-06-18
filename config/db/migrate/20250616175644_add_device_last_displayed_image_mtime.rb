ROM::SQL.migration do
  change do
    alter_table :devices do
      add_column :last_displayed_image_mtime, :timestamp, null: true
    end
  end
end