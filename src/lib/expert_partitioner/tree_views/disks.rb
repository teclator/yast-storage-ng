# encoding: utf-8

# Copyright (c) [2015] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "storage/extensions"
require "expert_partitioner/tree_views/view"
require "expert_partitioner/dialogs/format"
require "expert_partitioner/dialogs/create_partition_table"
require "expert_partitioner/dialogs/create_partition"
require "expert_partitioner/popups"

Yast.import "UI"
Yast.import "Popup"

include Yast::I18n
include Yast::Logger

module ExpertPartitioner
  class DisksTreeView < TreeView
    FIELDS = [:sid, :icon, :name, :size, :transport, :partition_table, :filesystem, :mountpoint]

    def initialize
      staging = storage.staging
      @disks = staging.all_disks
    end

    def create
      VBox(
        Left(IconAndHeading(_("Hard Disks"), Icons::DISK)),
        Table(Id(:table), Opt(:keepSorting), Storage::Device.table_header(FIELDS), items),
        HBox(
          PushButton(Id(:create), _("Create...")),
          PushButton(Id(:format), _("Format...")),
          PushButton(Id(:delete), _("Delete...")),
          HStretch()
        )
      )
    end

    def handle(input)
      case input

      when :create
        do_create_partition

      when :format
        do_format

      when :delete
        do_delete_partition

      end
    end

  private

    def items
      ret = []

      ::Storage.silence do

        @disks.each do |disk|

          ret << disk.table_row(FIELDS)

          begin
            partition_table = disk.partition_table
            partition_table.partitions.each do |partition|
              ret << partition.table_row(FIELDS)
            end
          rescue Storage::WrongNumberOfChildren, Storage::DeviceHasWrongType
          end

        end

      end

      return ret
    end

    def do_create_partition
      begin
        @disk.partition_table
      rescue Storage::WrongNumberOfChildren, Storage::DeviceHasWrongType
        Yast::Popup::Error("Disk has no partition table.")
        return
      end

      CreatePartitionDialog.new(@disk).run

      update(true)
    end

    def do_format
      sid = Yast::UI.QueryWidget(Id(:table), :CurrentItem)

      staging = storage.staging
      device = staging.find_device(sid)

      begin
        blk_device = Storage.to_blk_device(device)
        log.info "do_format #{sid} #{blk_device.name}"
        FormatDialog.new(blk_device).run
      rescue Storage::DeviceHasWrongType
        log.error "do_format on non blk device"
      end

      update(true)
    end

    def do_delete_partition
      sid = Yast::UI.QueryWidget(Id(:table), :CurrentItem)

      staging = storage.staging

      device = staging.find_device(sid)

      begin
        partition = Storage.to_partition(device)
      rescue Storage::WrongNumberOfChildren, Storage::DeviceHasWrongType
        Yast::Popup::Error("Only partitions can be deleted.")
        return
      end

      return unless RemoveDescendantsPopup.new(partition).run

      staging.remove_device(partition)
      update(true)
    end
  end
end
