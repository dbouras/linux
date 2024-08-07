#!/bin/bash
# SPDX-License-Identifier: GPL-2.0

# This test uses standard topology for testing gretap. See
# mirror_gre_topo_lib.sh for more details.
#
# Test for mirroring to gretap and ip6gretap, such that the neighbor entry for
# the tunnel remote address has invalid address at the time that the mirroring
# is set up. Later on, the neighbor is deleted and it is expected to be
# reinitialized using the usual ARP process, and the mirroring offload updated.

ALL_TESTS="
	test_gretap
	test_ip6gretap
"

NUM_NETIFS=6
source lib.sh
source mirror_lib.sh
source mirror_gre_lib.sh
source mirror_gre_topo_lib.sh

setup_prepare()
{
	h1=${NETIFS[p1]}
	swp1=${NETIFS[p2]}

	swp2=${NETIFS[p3]}
	h2=${NETIFS[p4]}

	swp3=${NETIFS[p5]}
	h3=${NETIFS[p6]}

	vrf_prepare
	mirror_gre_topo_create

	ip address add dev $swp3 192.0.2.129/28
	ip address add dev $h3 192.0.2.130/28

	ip address add dev $swp3 2001:db8:2::1/64
	ip address add dev $h3 2001:db8:2::2/64
}

cleanup()
{
	pre_cleanup

	ip address del dev $h3 2001:db8:2::2/64
	ip address del dev $swp3 2001:db8:2::1/64

	ip address del dev $h3 192.0.2.130/28
	ip address del dev $swp3 192.0.2.129/28

	mirror_gre_topo_destroy
	vrf_cleanup
}

test_span_gre_neigh()
{
	local addr=$1; shift
	local tundev=$1; shift
	local direction=$1; shift
	local forward_type=$1; shift
	local backward_type=$1; shift
	local what=$1; shift

	RET=0

	ip neigh replace dev $swp3 $addr lladdr 00:11:22:33:44:55
	mirror_install $swp1 $direction $tundev "matchall"
	fail_test_span_gre_dir $tundev "$forward_type" "$backward_type"
	ip neigh del dev $swp3 $addr
	quick_test_span_gre_dir $tundev "$forward_type" "$backward_type"
	mirror_uninstall $swp1 $direction

	log_test "$direction $what: neighbor change"
}

test_gretap()
{
	test_span_gre_neigh 192.0.2.130 gt4 ingress 8 0 "mirror to gretap"
	test_span_gre_neigh 192.0.2.130 gt4 egress 0 8 "mirror to gretap"
}

test_ip6gretap()
{
	test_span_gre_neigh 2001:db8:2::2 gt6 ingress 8 0 "mirror to ip6gretap"
	test_span_gre_neigh 2001:db8:2::2 gt6 egress 0 8 "mirror to ip6gretap"
}

trap cleanup EXIT

setup_prepare
setup_wait

tests_run

exit $EXIT_STATUS
