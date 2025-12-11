Sequel.migration do
  change do
    create_table(:frames) do
      primary_key :id
      String :frame_id, null: false, unique: true
      Text :context, null: false
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
    end

    create_table(:shacls) do
      primary_key :id
      String :shacl_id, null: false, unique: true
      Text :shape, null: false
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
    end

    create_table(:frames_shacls) do
      foreign_key :frame_id, :frames, on_delete: :cascade
      foreign_key :shacl_id, :shacls, on_delete: :cascade
      primary_key [:frame_id, :shacl_id]
    end
  end
end
