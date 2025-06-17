ROM::SQL.migration do
  change do
    alter_table :devices do
      # Change column type from timestamp to integer for storing file sizes
      set_column_type :last_displayed_image_mtime, :integer, using: 'NULL'
    end
  end
end