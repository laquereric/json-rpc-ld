class AddInputSchemaToMcpSkillSotSkills < ActiveRecord::Migration[7.0]
  def change
    add_column :mcp_skill_sot_skills, :input_schema, :text unless column_exists?(:mcp_skill_sot_skills, :input_schema)
  end
end
