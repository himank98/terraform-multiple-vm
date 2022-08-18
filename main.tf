locals {
  vm_datadiskdisk_count_map = { for k in toset(var.instances) : k => var.nb_disks_per_instance }
  luns                      = { for k in local.datadisk_lun_map : k.datadisk_name => k.lun }
  datadisk_lun_map = flatten([
    for vm_name, count in local.vm_datadiskdisk_count_map : [
      for i in range(count) : {
        datadisk_name = format("datadisk_%s_disk%02d", vm_name, i)
        lun           = i
      }
    ]
  ])
}

resource "azurerm_managed_disk" "managed_disk" {
  for_each             = toset([for j in local.datadisk_lun_map : j.datadisk_name])
  name                 = each.key
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 10
  tags                 = var.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "managed_disk_attach" {
  for_each           = toset([for j in local.datadisk_lun_map : j.datadisk_name])
  managed_disk_id    = azurerm_managed_disk.managed_disk[each.key].id
  virtual_machine_id = azurerm_linux_virtual_machine.vm[element(split("_", each.key), 1)].id
  lun                = lookup(local.luns, each.key)
  caching            = "ReadWrite"
}
