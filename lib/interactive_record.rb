require_relative "../config/environment.rb"
require 'active_support/inflector'

class InteractiveRecord
  def self.table_name
    self.to_s.downcase.pluralize
  end

  def self.column_names
    sql = "PRAGMA table_info(#{self.table_name})"
    column_info = DB[:conn].execute(sql)

    column_names = column_info.each_with_object(Array.new()) do |column, array|
      array << column['name']
    end
  end

  def self.find_by_name(name)
    sql = <<-SQL
      SELECT * FROM #{self.table_name}
      WHERE name = ?
      LIMIT 1
    SQL

    DB[:conn].execute(sql, name)
  end

  def self.find_by(parameter)
    search = parameter.each_with_object([]) do |(k,v), array|
      array << "#{k.to_s} = '#{v.to_s}'"
    end.flatten.join(' AND ')
    sql = <<-SQL
      SELECT * FROM #{self.table_name}
      WHERE #{search}
      LIMIT 1
    SQL

    DB[:conn].execute(sql)
  end
  ##################################################
  def initialize( options = {} )
    options.each do |attribute, value|
      self.send("#{attribute}=", value)
    end
  end

  def table_name_for_insert
    self.class.table_name
  end

  def col_names_for_insert
    self.class.column_names.delete_if { |column| column == 'id' }.join(', ')
  end

  def values_for_insert
    self.col_names_for_insert.split(', ').each_with_object([]) do |column_name, array|
      unless self.send("#{column_name}").nil?
        array << "'#{self.send("#{column_name}")}'"
      end
    end.join(', ')
  end

  def save
    if self.id
      update_table
    else
      insert_into_table
      id = DB[:conn].execute("SELECT last_insert_rowid() FROM #{self.table_name_for_insert}")
      self.id = id[0][0]
      self
    end
  end
  ##################################################
  private

  def insert_into_table
    sql = <<-SQL
      INSERT INTO #{self.table_name_for_insert} ( #{self.col_names_for_insert})
      VALUES (#{self.values_for_insert})
    SQL

    DB[:conn].execute(sql)
  end

  def update_table
    columns = self.col_names_for_insert.split(', ')
    values = self.values_for_insert.split(', ')
    column_value_pairs = columns.zip( values ).map do |value_array|
      "#{value_array[0]} = #{value_array[1]}"
    end.join(', ')

    sql = <<-SQL
      UPDATE #{self.table_name_for_insert}
      SET #{column_value_pairs}
      WHERE id = #{self.id}
    SQL
    DB[:conn].execute(sql)
  end
end
