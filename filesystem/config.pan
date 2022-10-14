# Template allow to configure partitionning with quite a lot of flexibility,
# based on externally defined variables.

unique template filesystem/config;

include 'quattor/functions/filesystem';


@{
desc =  template customizing the default disk layout provided by the default configuration
values = template namespace
default = null
required = no
}
variable FILESYSTEM_LAYOUT_CONFIG_SITE ?= null;

@{
desc =  template included at the beginning of the file system configuration and allowing to \
 to redefine the default size of block devices defined in the default configuration
values = template namespace
default = FILESYSTEM_LAYOUT_CONFIG_SITE+'-init' or null if FILESYSTEM_LAYOUT_CONFIG_SITE is undefined
required = no
}
variable FILESYSTEM_LAYOUT_CONFIG_INIT ?= if ( is_defined(FILESYSTEM_LAYOUT_CONFIG_SITE) ) {
                                            if_exists(FILESYSTEM_LAYOUT_CONFIG_SITE + '-init');
                                          } else {
                                            null;
                                          };

# The following variables define defaults for file systems and partitions.
# They are actually defined after including FILESYSTEM_LAYOUT_CONFIG_SITE.
#   - FILESYSTEM_DEFAULT_FS_TYPE: default file system type to use when none is specified
#   - FILESYSTEM_DEFAULT_PRESERVE: default file system preserve flag value
#   - FILESYSTEM_DEFAULT_FORMAT: default file system 'format' attribute
#   - FILESYSTEM_DEFAULT_MOUNTOPTS: default file system 'mountopts' attribute


# Function to update DISK_VOLUME_PARAMS.
# This function allows to merge site-specific volume parameters with default ones.
# Calling sequence is  :
#    variable DISK_VOLUME_PARAMS = filesystem_layout_mod(volume_dict);
# where 'volume_dict' has the same format as DISK_VOLUME_PARAMS.
function filesystem_layout_mod = {
  function_name = 'filesystem_layout_mod';
  if ( (ARGC != 1) || !is_dict(ARGV[0]) ) {
    error(function_name+': one argument required, must be a dict');
  };

  foreach (volume;params;ARGV[0]) {
    if ( exists(SELF[volume]) ) {
      foreach (key;value;params) {
        SELF[volume][key] = value;
      };
    } else {
      SELF[volume] = params;
    };
  };
  SELF;
};

function disk_part_name = {
    disk = ARGV[0];
    part_num = ARGV[1];

    if (exists("/hardware/harddisks/" + disk + "/part_prefix")) {
        part_prefix = value("/hardware/harddisks/" + disk + "/part_prefix");
    } else {
        part_prefix = "";
    };

    escape(unescape(disk) + part_prefix + to_string(part_num));
};


# Include site configuration initialization if any
include FILESYSTEM_LAYOUT_CONFIG_INIT;


# Retrieve boot device name based on HW configuration
@{
desc =  blockdevice used to boot
values = string
default = boot disk defined in the HW config
required = no
}
variable DISK_BOOT_DEV ?= boot_disk();
variable DISK_BOOT_DEV ?= {
  if (exists("/hardware/harddisks/sda")) {
    return("sda");
  } else if (exists("/hardware/harddisks/hda")) {
    return("hda");
  } else if (exists("/hardware/harddisks/xvda")) {
    return("xvda");
  } else if (exists("/hardware/harddisks/" + escape("cciss/c0d0"))) {
    return(escape("cciss/c0d0"));
  } else {
    error('Unable to locate primary disk');
  };
};

# Handle disk device names as /dev/cciss/xxxpn, where 'p' must be inserted
# between device name and partition number (e.g. HP SmartArray)
@{
desc =  partition name prefix (required when this is not the block device name)
values = string
default = part_prefix for the boot device if defined, else the empty string
required = no
}
variable DISK_BOOT_PART_PREFIX ?= if ( exists('/hardware/harddisks/'+DISK_BOOT_DEV+'/part_prefix') ) {
                                    value('/hardware/harddisks/'+DISK_BOOT_DEV+'/part_prefix');
                                  } else {
                                    '';
                                  };

# An ordered list of partition. Index will be used to build device name (index+1).
# Value is an arbitrary string.
variable DISK_BOOT_PARTS ?= list(
  'biosgrub',
  'boot',
  'root',
  'swap',
  'lvm',
);

@{
desc =  swap partition size
values = long
default = based on DISK_SWAP_RAM_RATIO
required = no
}
# The swap size should always be overridden in the archetype/filesystem-layouts
# templates. Hence setting it to undef to cause a compile error if it is not
# overridden.
variable DISK_SWAP_SIZE ?= undef;


# Variables related to GPT biosboot/UEFI support

@{
desc = define the default label for physical devices
values = string
default = gpt
required = no
}
variable PHYSICAL_DEVICE_DEFAULT_LABEL ?= "msdos";

@{
desc = the label for physical devices defined as dict.
values = dict whose keys are physical devices and values are labels \
 (msdos, gpt, ...)
default = null
required = no
}
variable PHYSICAL_DEVICE_LABEL ?= null;

@{
desc = indicates if a UEFI boot is used
values = boolean
default = false
required = no
}
variable DISK_BIOS_TYPE_UEFI ?= false;

# Add the required biosboot partition if the disk is using a GPT label, BIOS is using legacy mode
# Define biosboot partition size accordingly
@{
desc =  variable indicating that a biosboot partition must be unconditionally created
values = boolean
default = undef (actual value based on label used)
required = no
}
variable DISK_BOOT_ADD_BIOSBOOT_PART ?= undef;

@{
desc =  default size for block device biosboot if created
values = long
default = 100 MB for legacy BIOS
required = no
}
variable DISK_BIOSBOOT_BLOCKDEV_SIZE_DEFAULT ?= 100*MB;

@{
desc =  default size for block device efi bootdevice if UEFI is set.
values = long
default = 200 MB for UEFI when ufi is set
required = no
}
variable DISK_UEFIBOOT_BLOCKDEV_SIZE_DEFAULT ?= 200*MB;

# DISK_BIOSBOOT_BLOCKDEV_SIZE actually only defines the initial value
# that can be updated later based on DISK_BOOT_ADD_BIOSBOOT_PART, OS version and label
@{
desc =  size for block device biosboot and EFI
values = long
default = DISK_BIOSBOOT_BLOCKDEV_SIZE_DEFAULT if biosboot partition is created and OS version >= EL7, 0 otherwise
required = no
}
variable DISK_BIOSBOOT_BLOCKDEV_SIZE ?= 0;

# DISK_UEFIBOOT_BLOCKDEV_SIZE actually only defines the initial value
# can be updated late based on OS version and label, used only when DISK_BIOS_TYPE_UEFI is set.
@{
desc =  size for block device UEFI
values = long
default = DISK_UEFIBOOT_BLOCKDEV_SIZE_DEFAULT for efi partition created and OS version >= EL7, 0 otherwise
required = no
}
variable DISK_UEFIBOOT_BLOCKDEV_SIZE ?= 0;

@{
desc =  partition flags for biosboot partition
values = list of strings (matching valid partition flag names in blockdevices schema)
default = bios_grub for legacy BIOS
required = no
}
variable DISK_BIOSBOOT_PART_FLAGS ?= list('bios_grub');

@{
desc =  partition flags for efi boot partition
values = list of strings (matching valid partition flag names in blockdevices schema)
default = boot for UEFI
required = no
}
variable DISK_UEFIBOOT_PART_FLAGS ?= list('boot');

@{
desc = name of biosboot partition
values = string
default = biosboot for legacy BIOS, efi for UEFI
required = no
}
variable DISK_BIOSBOOT_PART_NAME ?= 'biosgrub';

@{
desc = name of UEFI partition
values = string
default = efi
required = no
}
variable DISK_UEFIBOOT_PART_NAME ?= 'efi';

@{
desc = fstype of UEFI BIOS boot partition
values = string
default = vfat (do no change unless you have a good reason to do it)
required = no
}
variable DISK_UEFI_BIOSBOOT_FSTYPE ?= 'vfat';

@{
desc = mountpoint of UEFI BIOS boot partition
values = string
default = /boot/efi (do no change unless you have a good reason to do it)
required = no
}
variable DISK_UEFI_BIOSBOOT_MOUNTPOINT ?= '/boot/efi';


# Variables related to volume sizes and names

@{
desc =  default size for block device boot
values = long
default = 256 MB
required = no
}
variable DISK_BOOT_BLOCKDEV_SIZE ?= 256*MB;

@{
desc =  default size for block device home
values = long
default = 0 (not created)
required = no
}
variable DISK_HOME_BLOCKDEV_SIZE ?= 0*GB;

@{
desc =  default size for block device opt
values = long
default = 2 GB
required = no
}
variable DISK_OPT_BLOCKDEV_SIZE ?= 2*GB;

@{
desc =  default size for block device root
values = long
default = 1 GB
required = no
}
variable DISK_ROOT_BLOCKDEV_SIZE ?= 1*GB;

@{
desc =  default size for block device swareas
values = long
default = 0 (not created)
required = no
}
variable DISK_SWAREAS_BLOCKDEV_SIZE ?= 0*GB;

@{
desc =  default size for block device tmp
values = long
default = 1 GB
required = no
}
variable DISK_TMP_BLOCKDEV_SIZE ?= 1*GB;

@{
desc =  default size for block device usr
values = long
default = 5 GB
required = no
}
variable DISK_USR_BLOCKDEV_SIZE ?= 5*GB;

@{
desc =  default size for block device var
values = long
default = -1 (remaining unused space)
required = no
}
variable DISK_VAR_BLOCKDEV_SIZE ?= -1;

@{
desc =  default size for block device vg.01
values = long
default = -1 (remaining unused space)
required = no
}
variable DISK_VG01_BLOCKDEV_SIZE ?= -1;

@{
desc =  default name for default volume group
values = string
default = vg.01
required = no
}
variable DISK_VG01_VOLGROUP_NAME ?= 'vg.01';


# Define list of volume (partition, logical volumes, md...).
# Default list is a disk with 4 partitions : /boot, /, swap and one partition for LVM.
# By default, LVM configuration is one logical volume for /usr, /opt, /var, /tmp with all
# the unused space in /var.
# Default layout can be adjusted to site-specific needs by tweaking this variable in template
# designated by FILESYSTEM_LAYOUT_CONFIG_SITE (this variable is defined when this template is executed).
# Key is an arbitrary name referenced by DISK_DEVICE_LIST.
@{
desc = dictionnary of volumes with their default paramaters that can be instantiated through the layout. \
 Normally, this dictionnary must not be redefined. To disable a volume, set its size to 0. Most parameters \
 can be tuned with a specific variable (see sources). New entries can be added by sites using filesystem_layout_mod()
values = key is a (free) volume name, value is a dict with the volume parameters (main keys are size, type, flags, \
 device, fstype, volgroup, mountpoint)
default = see sources
required = no
}
variable DISK_VOLUME_PARAMS ?= {
  if (DISK_BIOS_TYPE_UEFI) {
    SELF[DISK_UEFIBOOT_PART_NAME] = dict('size', DISK_UEFIBOOT_BLOCKDEV_SIZE,
                                       'type', 'partition',
                                       'flags', DISK_UEFIBOOT_PART_FLAGS,
                                       'device', disk_part_name(DISK_BOOT_DEV, index('boot',DISK_BOOT_PARTS) + 1));
  };
  SELF[DISK_BIOSBOOT_PART_NAME] = dict('size', DISK_BIOSBOOT_BLOCKDEV_SIZE,
                                       'type', 'partition',
                                       'flags', DISK_BIOSBOOT_PART_FLAGS,
                                       'device', disk_part_name(DISK_BOOT_DEV, index('biosgrub',DISK_BOOT_PARTS) + 1));
  SELF['boot'] = dict('size', DISK_BOOT_BLOCKDEV_SIZE,
                      'mountpoint', '/boot',
                      'fstype', 'ext2',
                      'type', 'partition',
                      'device', disk_part_name(DISK_BOOT_DEV, index('boot',DISK_BOOT_PARTS) + 1));
  SELF['home'] = dict('size', DISK_HOME_BLOCKDEV_SIZE,
                      'mountpoint', '/home',
                      'type', 'lvm',
                      'volgroup', DISK_VG01_VOLGROUP_NAME,
                      'device', 'homevol');
  SELF['opt'] = dict('size', DISK_OPT_BLOCKDEV_SIZE,
                     'mountpoint', '/opt',
                     'type', 'lvm',
                     'volgroup', DISK_VG01_VOLGROUP_NAME,
                     'device', 'optvol');
  SELF['root'] = dict('size', DISK_ROOT_BLOCKDEV_SIZE,
                      'mountpoint', '/',
                      'type', 'partition',
                      'device', disk_part_name(DISK_BOOT_DEV, index('root',DISK_BOOT_PARTS) + 1));
  SELF['swap'] = dict('size', DISK_SWAP_SIZE,
                      'mountpoint', 'swap',
                      'fstype', 'swap',
                      'type', 'partition',
                      'device', disk_part_name(DISK_BOOT_DEV, index('swap',DISK_BOOT_PARTS) + 1));
  SELF['swareas'] = dict('size', DISK_SWAREAS_BLOCKDEV_SIZE,
                         'mountpoint', '/swareas',
                         'type', 'lvm',
                         'volgroup', DISK_VG01_VOLGROUP_NAME,
                         'device', 'swareasvol');
  SELF['tmp'] = dict('size', DISK_TMP_BLOCKDEV_SIZE,
                     'mountpoint', '/tmp',
                     'type', 'lvm',
                     'volgroup', DISK_VG01_VOLGROUP_NAME,
                     'device', 'tmpvol');
  SELF['usr'] = dict('size', DISK_USR_BLOCKDEV_SIZE,
                     'mountpoint', '/usr',
                     'type', 'lvm',
                     'volgroup', DISK_VG01_VOLGROUP_NAME,
                     'device', 'usrvol');
  SELF['var'] = dict('size', DISK_VAR_BLOCKDEV_SIZE,
                     'mountpoint', '/var',
                     'type', 'lvm',
                     'volgroup', DISK_VG01_VOLGROUP_NAME,
                     'device', 'varvol');
  SELF[DISK_VG01_VOLGROUP_NAME] = dict('size', DISK_VG01_BLOCKDEV_SIZE,
                                       'type', 'vg',
                                       'devices', list(disk_part_name(DISK_BOOT_DEV, index('lvm',DISK_BOOT_PARTS) + 1)));
  SELF;
};

# List order of creation, for volume/partition where it matters
variable DISK_DEVICE_LIST ?= list('biosgrub',
                                  'boot',
                                  'root',
                                  'swap',
                                 );


# Define some defaults if not yet defined
@{
desc =  default file system type if not explictely defined for the partition/blockdevice
values = string
default = ext3
required = no
}
variable FILESYSTEM_DEFAULT_FS_TYPE ?= 'ext3';

# Include site-specific customization to volume list or creation order
include FILESYSTEM_LAYOUT_CONFIG_SITE;

@{
desc =  define whether a filesystem must be formatted or not by default
values = boolean
default = true
required = no
}
variable FILESYSTEM_DEFAULT_FORMAT ?= true;
@{
desc =  define whether a filesystem must be preserved or not by default
values = boolean
default = true
required = no
}
variable FILESYSTEM_DEFAULT_PRESERVE ?= true;
variable FILESYSTEM_DEFAULT_MOUNTOPTS ?= 'defaults';

# Enable ACLs only for the root disk for now. Walking the block device
# chain can be tricky e.g. in the presence of LVM, so use a pre-defined
# whitelist of mountpoints instead.
final variable ACL_MOUNTPOINT_ALLOWLIST = dict(
  escape("/"), true,
  escape("/var"), true,
  escape("/var/cache/ms"), true,
);

variable DISK_BOOT_ENABLE_ACLS ?= false;

# Remove entries with a zero size.
# Also ensure there is a type defined for every volume with a non-zero size.
# MD devices need a special treatment to ensure the devices they use have a non zero size. If
# all devices have a null size, md device is removed. If at least one has a non-zero size, device
# with a null size are removed from the list.
# The same sort of check must be done for file systems to ensure that if they don't have a size defined, the device
# they use has an entry in the volume list with a non-zero size (if there is no entry for the device used
# by the file system, a partition will be created but the file system must have a size defined).
# For raid1 MD devices (mirror), it is also possible to have the size defined at the MD level and no
# specific entries defined for the partitions used. In this case, add an entry for the underlying
# partitions with the appropriate size defined.
variable DISK_VOLUME_PARAMS = {
  volumes = dict();

  debug("Using disk layout = " + to_string(value("/system/archetype/filesystem-layout")));

  debug('Initial list of file systems: '+to_string(SELF));

  # Configure GPT legcay BIOS/UEFI boot partition if needed
  #   - Legacy BIOS: bios boot partition required if GPT is ued and OS version >= EL7
  #   - UEFI BIOS: GPT label and bios boot partition required
  define_biosboot_size = false;
  if (is_defined(PHYSICAL_DEVICE_LABEL) && exists(PHYSICAL_DEVICE_LABEL[DISK_BOOT_DEV])) {
    label = PHYSICAL_DEVICE_LABEL[DISK_BOOT_DEV];
  } else {
    label = PHYSICAL_DEVICE_DEFAULT_LABEL;
  };
  #  UEFI requires a GPT label and a bios boot partion
  if ( DISK_BIOS_TYPE_UEFI ) {
    if ( label == 'gpt') {
      define_biosboot_size = true;
    } else {
      error(format('UEFI BIOS requires a GPT label insted of %s',label));
    };
  };
  if ( is_defined(DISK_BOOT_ADD_BIOSBOOT_PART) ) {
    if ( DISK_BOOT_ADD_BIOSBOOT_PART ) {
      define_biosboot_size = true;
    } else if ( ! define_biosboot_size ) {
      SELF[DISK_BIOSBOOT_PART_NAME]['size'] = 0;
    };
  } else {
    if ( (label == 'gpt') &&
         #(is_defined(OS_VERSION_PARAMS['family']) && (OS_VERSION_PARAMS['family'] == 'el')) &&
         #(to_long(OS_VERSION_PARAMS['majorversion']) >= 7) ) {
         (AQUILON_OS_NAME == "linux") && (AQUILON_OS_MAJOR >= 7) ) {
      define_biosboot_size = true;
    };
  };
  if ( define_biosboot_size ) {
    if ( is_defined(SELF[DISK_BIOSBOOT_PART_NAME]) ) {
      if ( SELF[DISK_BIOSBOOT_PART_NAME]['size'] == 0 ) {
        SELF[DISK_BIOSBOOT_PART_NAME]['size'] = DISK_BIOSBOOT_BLOCKDEV_SIZE_DEFAULT;
      } else {
        debug(format("'%s' partition size already defined, default value not applied", DISK_BIOSBOOT_PART_NAME));
      };
    } else {
      debug(format("'%s' partition doesn't exist in DISK_VOLUME_PARAMS, size not defined", DISK_BIOSBOOT_PART_NAME));
    };

    if ( is_defined(SELF[DISK_UEFIBOOT_PART_NAME]) ) {
      if ( SELF[DISK_UEFIBOOT_PART_NAME]['size'] == 0 ) {
        SELF[DISK_UEFIBOOT_PART_NAME]['size'] = DISK_UEFIBOOT_BLOCKDEV_SIZE_DEFAULT;
      } else {
        debug(format("'%s' partition size already defined, default value not applied", DISK_UEFIBOOT_PART_NAME));
      };
    } else {
      debug(format("'%s' partition doesn't exist in DISK_VOLUME_PARAMS, size not defined", DISK_UEFIBOOT_PART_NAME));
    };
  };

  # set mountpoint and fsype for uefi
  if ( DISK_BIOS_TYPE_UEFI ) {
    if ( is_defined(SELF[DISK_UEFIBOOT_PART_NAME]) ) {
        SELF[DISK_UEFIBOOT_PART_NAME]['fstype'] = DISK_UEFI_BIOSBOOT_FSTYPE;
        SELF[DISK_UEFIBOOT_PART_NAME]['mountpoint'] = DISK_UEFI_BIOSBOOT_MOUNTPOINT;
    };
  };

  # MD-related checks
  foreach (volume;params;SELF) {
    if ( exists(params['type']) && (params['type'] == 'md') ) {
      if ( is_list(params['devices']) ) {
        md_dev_list = list();
        if ( exists(params['size']) && (params['size'] != 0) ) {
          # Create an entry for the underlying device with the appropriate size if it doesn't exist,
          # raid1 is used and size is defined for the MD device.
          foreach (i;device;params['devices']) {
            if ( !is_defined(SELF[device]) && exists(params['raid_level']) && (params['raid_level'] == 1) ) {
              volumes[device] = dict('device', device,
                                     'type', 'partition',
                                     'size', params['size']);
              debug('Entry added for partition '+device+' used by '+volume+' (size='+to_string(params['size'])+'MB)');
            };
          };
        } else {
          foreach (i;device;params['devices']) {
            if ( exists(SELF[device]['size']) && (SELF[device]['size'] != 0) ) {
              md_dev_list[length(md_dev_list)] = device;
            } else {
              debug('Device '+device+' removed from '+volume+' partition list');
            };
          };
          if ( length(md_dev_list) == 0 ) {
            # Mark md device for deletion by defining its size to 0
            debug('MD device '+volume+' has no partition left. Marking for deletion');
            params['size'] = 0;
          };
        };
      } else {
        error("MD device "+volume+": property 'devices' missing or not a list");
      };
    };
  };

  # File system related checks (a file system is recognized by its mountpoint attribute).
  # Ignore LVM-based file systems: check will be done later.
  foreach (volume;params;SELF) {
    if ( exists(params['mountpoint']) ) {
      if ( !exists(params['type']) || (params['type'] != 'lvm') ) {
        if ( exists(params['device']) ) {
          if ( is_defined(SELF[params['device']]) ) {
            if ( is_defined(SELF[params['device']]['size']) && (SELF[params['device']]['size'] == 0) ) {
              debug('Device '+params['device']+' used by file system '+volume+' has a zero size. Marking file system for deletion');
              params['size'] = 0;
            }
          } else if ( !is_defined(params['size']) ) {
            error("Filesystem "+volume+": size not specified but device "+params['device']+" has no explicitly entry");
          };
        } else {
          error("Filesystem "+volume+": 'device' property missing");
        };
      };
    };
  };

  # Remove all entries with a zero size
  foreach (volume;params;SELF) {
    if ( !exists(params['size']) || (params['size'] != 0) ) {
      if ( !exists(params['type']) ) {
        error('Type undefined for volume '+volume);
      };
      volumes[volume] = SELF[volume];
    } else {
      debug('Removing volume '+volume+' (size=0)');
    };
  };
  debug('New list of file systems: '+to_string(volumes));
  volumes;
};

# Update DISK_DEVICE_LIST to include all volumes in DISK_VOLUME_PARAMS, preserving original order,
# and removing volume present by default in this list but deleted in the configuration.
variable DISK_DEVICE_LIST = {
  volume_order = list();
  foreach (i;volume;SELF) {
    if ( is_defined(DISK_VOLUME_PARAMS[volume]) ) {
      volume_order[length(volume_order)] = volume;
    } else {
      debug('Removing '+volume+' from DISK_DEVICE_LIST (not used in configuration');
    };
  };
  foreach (volume;params;DISK_VOLUME_PARAMS) {
    if ( index(volume,SELF) < 0 ) {
      volume_order[length(volume_order)] = volume;
    };
  };
  debug('Volume processing order='+to_string(volume_order));
  volume_order;
};


# Build a list of partitions by physical device. This takes care of creating an entry for the
# partitions that are referenced without an explicit entry, ensuring that an extended partiton
# exists (it will be created if not done explicitly) if there are more than 4 partions and
# renumbering partitions for each device so that they use consecutive numbers.
#
# Note that an extended partition if explicitly declared must have a 'subtype' declared as
# 'extended'.
#
# DISK_PART_BY_DEV contains 2 different set of data:
#   - 'partitions': an entry with each partition and its parameters, grouped by physical disk
#   - 'changed_part_num': an entry for each partition renumbered to use a consecutive numbering. The
#                         keys are the original partition name, the value the new one.
variable DISK_PART_BY_DEV = {
  SELF['partitions'] = dict();
  SELF['changed_part_num'] = dict();
  foreach (i;dev_name;DISK_DEVICE_LIST) {
    if ( match(DISK_VOLUME_PARAMS[dev_name]['type'], 'md|vg') ) {
      if ( exists(DISK_VOLUME_PARAMS[dev_name]['devices']) ) {
        devices = DISK_VOLUME_PARAMS[dev_name]['devices'];
      } else {
        error('Missing physical device list for device '+dev_name);
      };
    } else {
      devices = list(dev_name);
    };

    foreach (j;device;devices) {
      # If the device is not present in DISK_VOLUME_PARAMS,
      # assume a partition using the unused part of the disk
      if ( exists(DISK_VOLUME_PARAMS[device]) ) {
        params = DISK_VOLUME_PARAMS[device];
      } else {
        debug('Adding an entry to DISK_PART_BY_DEV for partition '+device+' used by '+dev_name);
        params = dict('device', device,
                      'type', 'partition',
                      'size', -1);
      };
      if ( params['type'] == 'partition' ) {
        if ( !exists(params['device'])  ) {
          error("No physical device for partition '"+params['device']+"'");
        };
        phys_dev = null;
        part_num = null;
        part_prefix = null;
        foreach (key; info; value("/hardware/harddisks")) {
            if (exists(info["part_prefix"])) {
                pprefix = info["part_prefix"];
            } else {
                pprefix = "";
            };
            toks = matches(unescape(params['device']), '^('+ unescape(key) + ")" + pprefix + '(\d+)$');
            if ( length(toks) == 3 ) {
                phys_dev = key;
                part_num = to_long(toks[2]);
                part_prefix = pprefix;
            };
        };
        if (!is_defined(phys_dev)) {
            error('Invalid device name pattern ('+params['device']+')');
        };
        if ( !exists(SELF['partitions'][phys_dev]) ) {
          # Build 2 separate dict, part_list and part_num, the key being the partition name in each
          # list. part_list will be passed to partitions_add() which requires a dict of
          # partitions where the key is a partitionname and the value the partition parameters (as a dict).
          # part_num is a transient dict used internally to do the partition final numbering.
          SELF['partitions'][phys_dev] = dict('part_list', dict(),
                                              'part_num', dict(),
                                              'part_prefix', part_prefix,
                                              'extended', undef,
                                              'last_primary', 0,
                                             );
        };
        if ( is_defined(params['size']) ) {
          SELF['partitions'][phys_dev]['part_list'][params['device']]['size'] = params['size'];
        } else {
          # Assume rest of physical device by default
          SELF['partitions'][phys_dev]['part_list'][params['device']]['size'] = -1;
        };
        # 'flags' is a list of property that will be set to true in the block device configuration
        if ( is_defined(params['flags']) ) {
          SELF['partitions'][phys_dev]['part_list'][params['device']]['flags'] = params['flags'];
        };
        SELF['partitions'][phys_dev]['part_num'][params['device']] = part_num;
        if ( is_defined(params['subtype']) && (params['subtype'] == 'extended') ) {
          if ( is_defined(SELF['partitions'][phys_dev]['extended']) ) {
            error('Extended partition already defined for '+volume+' (number='+SELF['partitions'][phys_dev]['extended']+
                                                               '). Impossible to add a new one (number='+to_string(part_num)+')');
          } else {
            SELF['partitions'][phys_dev]['extended'] = part_num;
          };
        };
      };
    };
  };

  debug(format('Devices defined before partition renumbering = %s', to_string(SELF['partitions'])));

  # Process SELF['partitions'] and ensure that for each device, partition numbers are consecutive but keeping
  # logical partitions >=5. Renumbering cannot be used only based on the alphabetical order of partitions as
  # there may be 2 digits for the partition number.
  #
  # Another check is for partitions without an explicit size (size=-1). It is checked that there is no more
  # than one per disk and this partition will always be renumber to be the last one created.
  #
  # Note that this code heavily relies on the fact PAN dicts are run through in the lexical order by foreach
  # statement in panc v8. Should this change, this code would need to be fixed...

  foreach (phys_dev;dev_params;SELF['partitions']) {
    new_part_num = 1;
    new_part_list = dict();
    primary_no_size = list();
    logical_no_size = list();
    sorted_partition_list = list();
    two_digit_units = list();
    last_primary = SELF['partitions'][phys_dev]['last_primary'];
    if (is_defined(PHYSICAL_DEVICE_LABEL) && exists(PHYSICAL_DEVICE_LABEL[phys_dev])) {
      label = PHYSICAL_DEVICE_LABEL[phys_dev];
    } else {
       if (value("/hardware/harddisks/"+phys_dev+"/capacity") >= 2097152 ) {
        label = "gpt";
      } else {
        label = PHYSICAL_DEVICE_DEFAULT_LABEL;
      };
    };

    # First build the list of partitions sorted by partition number instead of lexical order
    # (10 after 9 and not after 1). This would not work with partition number >= 100 but this
    # is unlikely to happen...
    foreach (partition;part_num;SELF['partitions'][phys_dev]['part_num']) {
      if ( part_num >= 10 ) {
        two_digit_units[length(two_digit_units)] = partition;
      } else {
        sorted_partition_list[length(sorted_partition_list)] = partition;
      };
    };
    sorted_partition_list = merge(sorted_partition_list,two_digit_units);

    # Renumber partitions if necessary.
    foreach (i;partition;sorted_partition_list) {
      part_num = SELF['partitions'][phys_dev]['part_num'][partition];

      # Primary partitions: update last primary partition detected.
      # Also if the partition as no explicit size (size=-1), add it
      # to the list of primary partitions without and explicit size.
      # An extended partition is treated as a primary one at this point.
      if ( (part_num <= 4)  || (label == "gpt") ) {
        if ( SELF['partitions'][phys_dev]['part_list'][partition]['size'] == -1 ) {
          debug('Primary/extended partition '+partition+' has no size defined. Postponing allocation of a partition number.');
          primary_no_size[length(primary_no_size)] = part_num;
        } else{
          last_primary = new_part_num;
        };
      # Logical partitions: update to 5 next partition number to be assigned
      # to ensure a logical partition is not changed into a primary one.
      # Also keep track of the logical partitions without an explicit size.
      } else {
        if ( new_part_num <= 4 ) {
          new_part_num = 5;
        };
        if ( SELF['partitions'][phys_dev]['part_list'][partition]['size'] == -1 ) {
          debug('Logical partition '+partition+' has no size defined. Postponing allocation of a partition number.');
          logical_no_size[length(logical_no_size)] = part_num;
        };
      };
      # If the partition has no defined size (size=-1), ignore it at the moment.
      # It number will be assigned later.
      if ( SELF['partitions'][phys_dev]['part_list'][partition]['size'] != -1 ) {
        if ( part_num == new_part_num ) {
          new_part_name = partition;
        } else {
          new_part_name = replace(to_string(part_num)+'$',to_string(new_part_num),partition);
          debug('Renaming partition '+partition+' into '+new_part_name);
          SELF['changed_part_num'][partition] = new_part_name;
        };
        new_part_list[new_part_name] = SELF['partitions'][phys_dev]['part_list'][partition];
        new_part_num = new_part_num + 1;
      };
    };

    # No longer needed
    SELF['partitions'][phys_dev]['part_num'] = null;

    # Check that an extended partition has been explicitly defined, else create one if
    # there are partition numbers >=5 (last existing number used after renumbering is
    # new_part_num-1).
    if ( (new_part_num > 5) && !is_defined(SELF['partitions'][phys_dev]['extended']) && (label != 'gpt') ) {
      if ( last_primary == 0 ) {
        debug('No primary partition defined for '+phys_dev);
      };
      if ( last_primary == 4 ) {
        error('Need to create an extended partition on '+phys_dev+' but fourth partition already used and not defined as extended');
      } else {
        partition = phys_dev + SELF['partitions'][phys_dev]['part_prefix'] + to_string(last_primary+1);
        debug('Creating '+partition+' as an extended partition using unused part of '+phys_dev);
        new_part_list[partition]['size'] = -1;
        last_primary = last_primary + 1;
        SELF['partitions'][phys_dev]['extended'] = last_primary;
      };
    };

    # Check that there is no more than one partition without an explicit size and
    # assign it a number taking into accout if this is a primary or logical partition.
    foreach (listnum;no_size_list;list(primary_no_size,logical_no_size)) {
      if ( length(no_size_list) > 0 ) {
        old_part_name = phys_dev + SELF['partitions'][phys_dev]['part_prefix'] + to_string(no_size_list[0]);
        # Checks are different for primary and logical partitions
        if ( listnum == 0 ) {              # Primary partitions
          if ( (length(no_size_list) > 1) ||
               ((length(no_size_list) == 1) &&
                 is_defined(SELF['partitions'][phys_dev]['extended']) &&
                 (no_size_list[0] != SELF['partitions'][phys_dev]['extended']) ) ) {
            if ( is_defined(SELF['partitions'][phys_dev]['extended']) ) {
              extended_msg='and 1 extended';
            } else {
              extended_msg='';
            };
            error(to_string(length(no_size_list))+' primary '+to_string(no_size_list)+' '+extended_msg+
                                           ' partitions found on '+phys_dev+' without an explicit size defined');
          };
          if ( (last_primary >= 4) && (label != 'gpt') ) {
            error('Cannot add partition (formerly) '+old_part_name+': 4 primary partitions already defined');
          };
          no_size_part_num = last_primary + 1;
        } else {                           # Logical partitions
          if ( length(no_size_list) > 1 ) {
            error(to_string(length(no_size_list))+' logical partitions '+to_string(no_size_list)+' found on '+phys_dev+
                                         ' without an explicit size defined(');
          };
          if ( new_part_num <= 4 ) {
            new_part_num = 5;
          };
          no_size_part_num = new_part_num;
        };

        new_part_name = phys_dev + SELF['partitions'][phys_dev]['part_prefix'] + to_string(no_size_part_num);
        debug('Assigning partition name '+new_part_name+' to former '+old_part_name+' (no explicit size)');
        new_part_list[new_part_name]['size'] = -1;
        if ( old_part_name != new_part_name ) {
          SELF['changed_part_num'][old_part_name] = new_part_name;
        };
      };
    };

    # Assign the new list of partition for the device.
    SELF['partitions'][phys_dev]['part_list'] = new_part_list;
  };

  debug(format('Renumbered partitions = %s', to_string(SELF['changed_part_num'])));
  debug(format('Devices defined after partition renumbering = %s', to_string(SELF['partitions'])));

  SELF;
};

# Update DISK_VOLUME_PARAMS to reflect changed partition names/numbers in the device attribute for
# partitions, VG and MD in order to be consistent with DISK_PART_BY_DEV. For VG and MD, it must be done
# only if the device is not in DISK_VOLUME_PARAMS (partition automatically created in DISK_PART_BY_DEV).
# A flag, 'final', is added to the entry to help with possible loops when processing
# DISK_VOLUME_PARAMS: this flag explicitly states that this entry correspond to a
# physical partition description and that no attempt should be made to dereference it.
variable DISK_VOLUME_PARAMS = {
  foreach (volume;params;SELF) {
    if ( (params['type'] == 'partition') &&
         is_defined(DISK_PART_BY_DEV['changed_part_num'][params['device']]) ) {
      debug(format('%s: updating %s device to new partition name/number: %s',
                              OBJECT, volume, DISK_PART_BY_DEV['changed_part_num'][params['device']]));
      params['device'] = DISK_PART_BY_DEV['changed_part_num'][params['device']];
      params['final'] = true;
    } else if ( match(params['type'],'md|vg') ) {
      dev_list = list();
      dev_list_updated = false;
      foreach(i;dev;params['devices']) {
        if ( !is_defined(DISK_VOLUME_PARAMS[dev]) &&
             is_defined(DISK_PART_BY_DEV['changed_part_num'][dev]) ) {
          debug(format('%s: updating %s device %s to new partition name/number: %s',
                              OBJECT, volume, dev, DISK_PART_BY_DEV['changed_part_num'][dev]));
          dev_list[length(dev_list)] = DISK_PART_BY_DEV['changed_part_num'][dev];
          dev_list_updated = true;
        } else {
          dev_list[length(dev_list)] = dev;
        };
      };
      if ( dev_list_updated ) debug(format('%s new device list = %s', volume, to_string(dev_list)));
      params['devices'] = dev_list;
    };
  };
  SELF;
};

#Create physical devices
"/system/blockdevices/physical_devs" = {
  foreach (phys_dev;params;DISK_PART_BY_DEV['partitions']) {
    if (is_defined(PHYSICAL_DEVICE_LABEL) && exists(PHYSICAL_DEVICE_LABEL[phys_dev])) {
      label = PHYSICAL_DEVICE_LABEL[phys_dev];
    } else {
       if (value("/hardware/harddisks/"+phys_dev+"/capacity") >= 2097152 ) {
        label = "gpt";
      } else {
        label = PHYSICAL_DEVICE_DEFAULT_LABEL;
      };
    };
    SELF[phys_dev] = dict ("label", label);
  };
  SELF;
};

# Create partitions.
# Configuration validity has already been checked.
"/system/blockdevices/partitions" = {
  foreach (phys_dev;params;DISK_PART_BY_DEV['partitions']) {
    if ( is_defined(DISK_PART_BY_DEV['partitions'][phys_dev]['extended']) ) {
      extended_part = phys_dev + DISK_PART_BY_DEV['partitions'][phys_dev]['part_prefix'] +
                                            to_string(DISK_PART_BY_DEV['partitions'][phys_dev]['extended']);
      partitions_add (phys_dev, params['part_list'], extended_part);
    } else {
      partitions_add (phys_dev, params['part_list']);
    };
  };
  SELF;
};

# Add MD and VG definitions
"/system/blockdevices" = {
  foreach (i;dev_name;DISK_DEVICE_LIST) {
    params = DISK_VOLUME_PARAMS[dev_name];
    if ( match(params['type'],'md|vg') ) {
      # First build partition list with the appropriate name.
      # Dereference until it is a real partition.
      partitions = list();
      foreach (j;device;params['devices']) {
        part_not_found = true;
        part_name = device;
        debug('Looking for partition name corresponding to '+device+' used by '+dev_name);
        # Device names listed by MD or VG entries are derefenced using other entries in DISK_VOLUME_PARAMS
        # until the actual partition to use has been found.
        # The actual partition entry is identified either by having a 'final' flag defined and
        # set to true (this is done as part of the partition renumbering to avoid resulting possible loops)
        # or by the device name associated with the entry to be the same as the entry name or
        # or by the entry missing in DISK_VOLUME_PARAMS (implicitly created in DISK_PART_BY_DEV).
        # It is very important for all partition entries matching actual partitions to have the
        # final flag set if the device name associated with them doesn't match the entry name.
        # Check the device identified is found in /system/blockdevices/partitions, else
        # raise an error. Something wrong happened before...
        while ( part_not_found ) {
          if ( is_defined(DISK_VOLUME_PARAMS[part_name]) ) {
            part_name = DISK_VOLUME_PARAMS[part_name]['device'];
          };
          if ( !is_defined(DISK_VOLUME_PARAMS[part_name]) ||
               (is_defined(DISK_VOLUME_PARAMS[part_name]['final']) && DISK_VOLUME_PARAMS[part_name]['final']) ||
               (is_defined(DISK_VOLUME_PARAMS[part_name]['device']) && (DISK_VOLUME_PARAMS[part_name]['device'] == part_name)) ) {
            part_not_found = false;
          };
        };
        if ( !is_defined(SELF['partitions'][part_name]) ) {
          error('Partition '+part_name+' is used by '+dev_name+
                                       ' but has no entry under /system/blockdevices/partitions');
        };
        debug('Found: '+part_name);
        partitions[length(partitions)] = "partitions/" + part_name;
      };
      if ( params['type'] == 'md') {
        if ( !exists(SELF['md']) ) {
          SELF['md'] = dict();
        };
        if ( exists(params['raid_level']) ) {
          raid_level = 'RAID'+to_string(params['raid_level']);
        } else {
          raid_level = 'RAID0';
        };
        SELF['md'][dev_name] = dict("device_list", partitions,
                                    "raid_level", raid_level);
      } else if ( params['type'] == 'vg' ) {
         if ( !exists(SELF['volume_groups']) ) {
          SELF['volume_groups'] = dict();
        };
        SELF['volume_groups'][dev_name] = dict("device_list", partitions);
      };
    };
  };

  SELF;
};

# Build a list of logical volumes per volume group.
# They will be properly ordered at creation time, based on file system
# creation order.
variable DISK_LV_BY_VG = {
  foreach (i;device;DISK_DEVICE_LIST) {
    params = DISK_VOLUME_PARAMS[device];
    if ( params['type'] == 'lvm' ) {
      # Already checked for existence
      params = DISK_VOLUME_PARAMS[device];

      if ( !exists(params['device'])  ) {
        error("Logical volume name undefined for '"+device+"'");
      };
      if ( exists(params['volgroup'])  ) {
        vg_name = params['volgroup'];
      } else {
        error("No volume group defined for logical volume '"+params['device']+"'");
      };
      if ( !exists(SELF[vg_name]) ) {
        SELF[vg_name] = dict();
      };
      if ( exists(params['size']) ) {
        SELF[vg_name][params['size']] = params['size'];
      } else {
        error('Size has not been specified for logical volume '+params['device']);
      };
    };
  };

  SELF;
};

"/system/blockdevices/logical_volumes" = {
  if ( is_defined(DISK_LV_BY_VG) ) {
    foreach (vg_name;lv_list;DISK_LV_BY_VG) {
      lvs_add (vg_name, lv_list);
    };
    SELF;
  } else {
    debug('No logical volumes found');
    null;
  };
};


# Create/connfigure file systems.
# Ignore entries in this list that have no mount point defined.
# Take care of creating logical volume without a defined size last in the volume group.
"/system/filesystems" = {
  # Create a list of volume per volume group (other partitions/volumes set in 'OTHERS__').
  volumes = dict();
  lastgroup = dict();
  defgroup_name = 'OTHERS__';
  volgroups = list(defgroup_name);     # Use to control creation order
  foreach (i;dev_name;DISK_DEVICE_LIST) {
    params = DISK_VOLUME_PARAMS[dev_name];
    if ( params['type'] == 'lvm' ) {
      volgroup = params['volgroup'];
      if ( !exists(volumes[volgroup]) ) {
        volumes[volgroup] = list();
        volgroups[length(volgroups)] = volgroup;
      };
      if ( params['size'] == -1 ) {
        # Use a list for lastgroup to allow more useful diagnostics...
        if ( !exists(lastgroup[volgroup]) ) {
          lastgroup[volgroup] = list();
        };
        lastgroup[volgroup][length(lastgroup[volgroup])] = dev_name;
      } else {
        volumes[volgroup][length(volumes[volgroup])] = dev_name;
      };
    } else {
      if ( !exists(volumes[defgroup_name]) ) {
        volumes[defgroup_name] = list();
      };
      volumes[defgroup_name][length(volumes[defgroup_name])] = dev_name;
    };
  };

  # Add logical volumes that must be created last in each volume group
  # because they have no expicit size defined.
  # Check there is just one such logical volume per volume group.
  foreach (volgroup;logvols;lastgroup) {
    # If an entry exist for a vg, there is at least one entry in it.
    if ( length(logvols) > 1 ) {
      error('Several logical volumes with an undefined size in volume group '+volgroup+' '+to_string(logvols));
    };
    volumes[volgroup][length(volumes[volgroup])] = logvols[0];
  };
  # Add configuration information for each file system
  foreach (i;volgroup;volgroups) {
    foreach (i;dev_name;volumes[volgroup]) {
      params = DISK_VOLUME_PARAMS[dev_name];
      if ( exists(params['mountpoint']) ) {
        if ( params['type'] == 'partition' ) {
          block_device = 'partitions/' + params['device'];
        } else if ( params['type'] == 'lvm' ) {
          block_device = 'logical_volumes/' + params['device'];
        } else if ( params['type'] == 'raid' ) {
          block_device = 'md/' + params['device'];
        };

        if ( exists(params['fstype']) ) {
          fs_type = params['fstype'];
        } else {
          fs_type = FILESYSTEM_DEFAULT_FS_TYPE;
        };
        if ( exists(params['format']) ) {
          format = params['format'];
        } else {
          format = FILESYSTEM_DEFAULT_FORMAT;
        };
        if ( exists(params['preserve']) ) {
          preserve = params['preserve'];
        } else {
          preserve = FILESYSTEM_DEFAULT_PRESERVE;
        };
        if ( exists(params['mountopts']) ) {
          mountopts = params['mountopts'];
        } else {
          mountopts = FILESYSTEM_DEFAULT_MOUNTOPTS;
        };
        if ( exists(params['mount']) ) {
          mount = params['mount'];
        } else {
          mount = true;
        };
        fs_params = dict ("block_device", block_device,
                          "mountpoint", params['mountpoint'],
                          "format", format,
                          "mount", mount,
                          "preserve", preserve,
                          "type", fs_type,
                          "mountopts", mountopts);
        # Copy the optional parameters if present
        foreach (i; name; list("freq", "pass", "mkfsopts", "tuneopts", "label", "quota")) {
          if (exists(params[name])) {
            fs_params[name] = params[name];
          };
        };
        filesystem_mod(fs_params);
      };
    };
  };
  SELF;
};

# Requirements for mount options may come from multiple sources:
#
# - OS settings (e.g. panic in case of errors on the root fs)
# - backend-specific settings (e.g. noatime/relatime on virtual disks)
# - user feature requests (e.g. turn on ACLs)
#
# The loop above took care about the first two cases, now let's handle the
# third.
"/system/filesystems" = {
  foreach (idx; params; SELF) {
    if (DISK_BOOT_ENABLE_ACLS && exists(ACL_MOUNTPOINT_ALLOWLIST[escape(params["mountpoint"])])) {
      if (params["type"] == "ext3" || params["type"] == "ext4") {
         SELF[idx]["mountopts"] = params["mountopts"] + ",acl";
      };
    };
  };
  SELF;
};

# Set requested permissions or owner (if any) on filesystem mountpoints
include 'components/dirperm/config';
'/software/components/dirperm' = {
  if ( !exists(SELF['paths']) || !is_defined(SELF['paths']) ) {
    SELF['paths'] = list();
  };
  foreach (i;dev_name;DISK_DEVICE_LIST) {
    params = DISK_VOLUME_PARAMS[dev_name];
    if ( (exists(params['permissions']) || exists(params['owner'])) && exists(params['mountpoint']) ) {
      path_params = dict('path', params['mountpoint'],
                         'type', 'd');
      if ( exists(params['owner']) ) {
        path_params['owner'] = params['owner'];
      } else {
        path_params['owner'] = 'root:root';
      };
      if ( exists(params['permissions']) ) {
        path_params['perm'] = params['permissions'];
      } else {
        path_params['perm'] = '0755';
      };
      SELF['paths'][length(SELF['paths'])] = path_params
    };
  };

  SELF;
};
