class SampleTable < ActiveRecord::Migration
  def up
    create_table :sample_table do |t|
      t.column :name, :string, :null => false
    end
  end
  def down
    drop_table :sample_table
  end
end
