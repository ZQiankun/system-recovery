# /bin/sh
#
# ADD_ON Script and it will be executed at the end of install progress
#

CDROM="/run/initramfs/live"
ROOT="/mnt/sysimage"
LOGFILE="/tmp/addon-install.log"
MNTPOINT="/tmp/fsarchiver"

### stop crond.service
chroot $ROOT /bin/bash -c "systemctl stop crond.service"

### add qingxin theme
tar xjvf $CDROM/ADD_ON/ty-update/qingxin-theme.tar.bz2  -C $ROOT

rpm -e firstboot --root=$ROOT

sed -i -e '$a\NoDisplay=true' $ROOT/usr/share/applications/mate-session-properties.desktop # 启动应用程序

################## post ############################
if [ -e "/var/tmp/factorymode" ]; then
        # update grub.cfg, add menu
        INSERT_LINE=`sed -n "/Rescue Mode/=" $ROOT/boot/grub/grub.cfg`
        let INSERT_LINE--
        #sed -i "$INSERT_LINE r $CDROM/ADD_ON/system-backup-restore.cfg" $ROOT/boot/grub/grub.cfg
        chroot $ROOT grub2-install --no-floppy  /dev/sda

        # preserve date mode and backup
        if [ -e "/var/tmp/XGS_USER_DATA" ]; then
                # data
                \cp  -f /var/tmp/uData/* $ROOT/etc/
         #       echo '/dev/sda5 /home ext4 defaults,nodev,nosuid 1 2' >> $ROOT/etc/fstab
                chroot $ROOT /bin/bash -c "chown root:root /etc/passwd && chown root:root /etc/shadow"

                echo "preserve-data-inst progress completed!" >> $LOGFILE
        else
                # backup system  pre
                mkdir -p $MNTPOINT
                mount /dev/sda3 $MNTPOINT
                mkdir -p $MNTPOINT/backup

                # dd livecd iso to backup partation
                echo "dd livecd to sda3" >> $LOGFILE
                SOURCE_DEV=`mount | grep /run/initramfs/live | cut -d ' ' -f1`
                dd if=$SOURCE_DEV of=$MNTPOINT/.boot.iso bs=2048
                echo "dd completed!" >> $LOGFILE

                # begin to backup /dev/sda1
		fuser -km $ROOT
                umount -Rf $ROOT

                # fsarchiver -j4 -o savefs $MNTPOINT/backup/backup_factory.fsa /dev/sda1 /dev/sda5 &>> $LOGFILE
                fsarchiver -j4 -o savefs $MNTPOINT/backup/backup_factory.fsa /dev/sda1 &>> $LOGFILE
                if [ $? -eq 0 ]; then
                        echo "backup successful !" >> $LOGFILE
                else
                        echo "backup error!" >> $LOGFILE
                fi
                mount   /dev/sda1  $ROOT
                mount   /dev/sda5  $ROOT/home
                mount   /dev/sda6  $ROOT/var/log
                umount -f $MNTPOINT  >> $LOGFILE

                echo "factroyinst progress completed!" >> $LOGFILE
        fi
fi
