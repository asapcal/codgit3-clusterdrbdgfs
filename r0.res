#“r0.res” -> “/etc/drbd.d/”.
global {
	usage-count no;
}    


resource r0 {
        protocol C;

        syncer {
		#rate 100M;
		verify-alg sha1;
        }
        startup {
                wfc-timeout 0;
                # non-zero wfc-timeout can be dangerous
                degr-wfc-timeout 120;
                outdated-wfc-timeout 120;
                become-primary-on both;
        }
        disk {
                resync-rate
                33M;
                c-max-rate 110M;
                c-min-rate 10M;
                c-fill-target 16M;
                #fencing resource-and-stonith;
                no-disk-barrier;
                no-disk-flushes;
        }
        net {
                cram-hmac-alg sha1;
                shared-secret "my-secret";
                use-rle yes;
                allow-two-primaries yes;
                after-sb-0pri discard-zero-changes;
                after-sb-1pri discard-secondary;
                after-sb-2pri disconnect;
        }
        handlers {
                fence-peer"/usr/lib/drbd/rhcs_fence";
}
        on vm1.cluster {
                        device /dev/drbd0;
                        disk /dev/fileserver/r0;
                        address 10.255.255.x:7788;
                        meta-disk internal;
        }
        on vm2.cluster {
                        device /dev/drbd0;
                        disk /dev/fileserver/r0;
                        address 10.255.255.x:7788;
                        meta-disk internal;
        }
}
