#!/bin/bash

start_redir(){
	#获取局域网host地址
	getlanip
	#流量过滤
	iptables -t nat -N clash
	for ip in $host_ipv4 $reserve_ipv4;do #跳过目标保留地址及目标本机网段
		iptables -t nat -A clash -d $ip -j RETURN
	done
	#绕过CN_IP
	[ "$dns_mod" = "redir_host" -a "$cn_ip_route" = "已开启" ] && \
	iptables -t nat -A clash -m set --match-set cn_ip dst -j RETURN 2>/dev/null
	#局域网设备过滤
	if [ "$macfilter_type" = "白名单" -a -n "$(cat $clashdir/configs/mac)" ];then
		for mac in $(cat $clashdir/configs/mac); do #mac白名单
			iptables -t nat -A clash -p tcp -m mac --mac-source $mac -j REDIRECT --to-ports $redir_port
		done
	else
		for mac in $(cat $clashdir/configs/mac); do #mac黑名单
			iptables -t nat -A clash -m mac --mac-source $mac -j RETURN
		done
		#仅代理本机局域网网段流量
		for ip in $host_ipv4;do
			iptables -t nat -A clash -p tcp -s $ip -j REDIRECT --to-ports $redir_port
		done
	fi
	#将PREROUTING链指向clash链
	iptables -t nat -A PREROUTING -p tcp $ports -j clash
	[ "$dns_mod" = "fake-ip" -a "$common_ports" = "已开启" ] && iptables -t nat -A PREROUTING -p tcp -d 198.18.0.0/16 -j clash
	#设置ipv6转发
	if [ "$ipv6_redir" = "已开启" -a -n "$(lsmod | grep 'ip6table_nat')" ];then
		ip6tables -t nat -N clashv6
		for ip in $reserve_ipv6 $host_ipv6;do #跳过目标保留地址及目标本机网段
			ip6tables -t nat -A clashv6 -d $ip -j RETURN
		done
		#绕过CN_IPV6
		[ "$dns_mod" = "redir_host" -a "$cn_ipv6_route" = "已开启" ] && \
		ip6tables -t nat -A clashv6 -m set --match-set cn_ip6 dst -j RETURN 2>/dev/null
		#局域网设备过滤
		if [ "$macfilter_type" = "白名单" -a -n "$(cat $clashdir/configs/mac)" ];then
			for mac in $(cat $clashdir/configs/mac); do #mac白名单
				ip6tables -t nat -A clashv6 -p tcp -m mac --mac-source $mac -j REDIRECT --to-ports $redir_port
			done
		else
			for mac in $(cat $clashdir/configs/mac); do #mac黑名单
				ip6tables -t nat -A clashv6 -m mac --mac-source $mac -j RETURN
			done
			#仅代理本机局域网网段流量
			for ip in $host_ipv6;do
				ip6tables -t nat -A clashv6 -p tcp -s $ip -j REDIRECT --to-ports $redir_port
			done
		fi
		ip6tables -t nat -A PREROUTING -p tcp $ports -j clashv6
	fi
	return 0
}
start_ipt_dns(){
	#屏蔽OpenWrt内置53端口转发
	[ "$(uci get dhcp.@dnsmasq[0].dns_redirect 2>/dev/null)" = 1 ] && {
		uci del dhcp.@dnsmasq[0].dns_redirect
		uci commit dhcp.@dnsmasq[0]
	}
	#设置dns转发
	iptables -t nat -N clash_dns
	if [ "$macfilter_type" = "白名单" -a -n "$(cat $clashdir/configs/mac)" ];then
		for mac in $(cat $clashdir/configs/mac); do #mac白名单
			iptables -t nat -A clash_dns -p udp -m mac --mac-source $mac -j REDIRECT --to $dns_port
		done
	else
		for mac in $(cat $clashdir/configs/mac); do #mac黑名单
			iptables -t nat -A clash_dns -m mac --mac-source $mac -j RETURN
		done	
		iptables -t nat -A clash_dns -p udp -j REDIRECT --to $dns_port
	fi
	iptables -t nat -I PREROUTING -p udp --dport 53 -j clash_dns
	#ipv6DNS
	if [ -n "$(lsmod | grep 'ip6table_nat')" -a -n "$(lsmod | grep 'xt_nat')" ];then
		ip6tables -t nat -N clashv6_dns > /dev/null 2>&1
		if [ "$macfilter_type" = "白名单" -a -n "$(cat $clashdir/configs/mac)" ];then
			for mac in $(cat $clashdir/configs/mac); do #mac白名单
				ip6tables -t nat -A clashv6_dns -p udp -m mac --mac-source $mac -j REDIRECT --to $dns_port
			done
		else
			for mac in $(cat $clashdir/configs/mac); do #mac黑名单
				ip6tables -t nat -A clashv6_dns -m mac --mac-source $mac -j RETURN
			done	
			ip6tables -t nat -A clashv6_dns -p udp -j REDIRECT --to $dns_port
		fi
		ip6tables -t nat -I PREROUTING -p udp --dport 53 -j clashv6_dns
	else
		ip6tables -I INPUT -p udp --dport 53 -m comment --comment "ShellClash-IPV6_DNS-REJECT" -j REJECT 2>/dev/null
	fi
	return 0

}
start_tproxy(){
	#获取局域网host地址
	getlanip
	modprobe xt_TPROXY &>/dev/null
	ip rule add fwmark $fwmark table 100
	ip route add local default dev lo table 100
	iptables -t mangle -N clash
	iptables -t mangle -A clash -p udp --dport 53 -j RETURN
	for ip in $host_ipv4 $reserve_ipv4;do #跳过目标保留地址及目标本机网段
		iptables -t mangle -A clash -d $ip -j RETURN
	done
	#绕过CN_IP
	[ "$dns_mod" = "redir_host" -a "$cn_ip_route" = "已开启" ] && \
	iptables -t mangle -A clash -m set --match-set cn_ip dst -j RETURN 2>/dev/null
	#tcp&udp分别进代理链
	tproxy_set(){
	if [ "$macfilter_type" = "白名单" -a -n "$(cat $clashdir/configs/mac)" ];then
		for mac in $(cat $clashdir/configs/mac); do #mac白名单
			iptables -t mangle -A clash -p $1 -m mac --mac-source $mac -j TPROXY --on-port $tproxy_port --tproxy-mark $fwmark
		done
	else
		for mac in $(cat $clashdir/configs/mac); do #mac黑名单
			iptables -t mangle -A clash -m mac --mac-source $mac -j RETURN
		done
		#仅代理本机局域网网段流量
		for ip in $host_ipv4;do
			iptables -t mangle -A clash -p $1 -s $ip -j TPROXY --on-port $tproxy_port --tproxy-mark $fwmark
		done			
	fi
	iptables -t mangle -A PREROUTING -p $1 $ports -j clash
	[ "$dns_mod" = "fake-ip" -a "$common_ports" = "已开启" ] && iptables -t mangle -A PREROUTING -p $1 -d 198.18.0.0/16 -j clash
	}
	[ "$1" = "all" ] && tproxy_set tcp
	tproxy_set udp
	
	#屏蔽QUIC
	[ "$quic_rj" = 已启用 ] && {
		[ "$dns_mod" = "redir_host" -a "$cn_ip_route" = "已开启" ] && set_cn_ip='-m set ! --match-set cn_ip dst'
		iptables -I INPUT -p udp --dport 443 -m comment --comment "ShellClash-QUIC-REJECT" $set_cn_ip -j REJECT >/dev/null 2>&1
	}
	#设置ipv6转发
	[ "$ipv6_redir" = "已开启" ] && {
		ip -6 rule add fwmark $fwmark table 101
		ip -6 route add local ::/0 dev lo table 101
		ip6tables -t mangle -N clashv6
		ip6tables -t mangle -A clashv6 -p udp --dport 53 -j RETURN
		for ip in $host_ipv6 $reserve_ipv6;do #跳过目标保留地址及目标本机网段
			ip6tables -t mangle -A clashv6 -d $ip -j RETURN
		done
		#绕过CN_IPV6
		[ "$dns_mod" = "redir_host" -a "$cn_ipv6_route" = "已开启" ] && \
		ip6tables -t mangle -A clashv6 -m set --match-set cn_ip6 dst -j RETURN 2>/dev/null
		#tcp&udp分别进代理链
		tproxy_set6(){
			if [ "$macfilter_type" = "白名单" -a -n "$(cat $clashdir/configs/mac)" ];then
				#mac白名单
				for mac in $(cat $clashdir/configs/mac); do
					ip6tables -t mangle -A clashv6 -p $1 -m mac --mac-source $mac -j TPROXY --on-port $tproxy_port --tproxy-mark $fwmark
				done
			else
				#mac黑名单
				for mac in $(cat $clashdir/configs/mac); do
					ip6tables -t mangle -A clashv6 -m mac --mac-source $mac -j RETURN
				done
				#仅代理本机局域网网段流量
				for ip in $host_ipv6;do
					ip6tables -t mangle -A clashv6 -p $1 -s $ip -j TPROXY --on-port $tproxy_port --tproxy-mark $fwmark
				done
			fi	
			ip6tables -t mangle -A PREROUTING -p $1 $ports -j clashv6		
		}
		[ "$1" = "all" ] && tproxy_set6 tcp
		tproxy_set6 udp
		
		#屏蔽QUIC
		[ "$quic_rj" = 已启用 ] && {
			[ "$dns_mod" = "redir_host" -a "$cn_ipv6_route" = "已开启" ] && set_cn_ip6='-m set ! --match-set cn_ip6 dst'
			ip6tables -I INPUT -p udp --dport 443 -m comment --comment "ShellClash-QUIC-REJECT" $set_cn_ip6 -j REJECT 2>/dev/null
		}	
	}
}
start_output(){
	#获取局域网host地址
	getlanip
	#流量过滤
	iptables -t nat -N clash_out
	iptables -t nat -A clash_out -m owner --gid-owner 7890 -j RETURN
	for ip in $local_ipv4 $reserve_ipv4;do #跳过目标保留地址及目标本机网段
		iptables -t nat -A clash_out -d $ip -j RETURN
	done
	#绕过CN_IP
	[ "$dns_mod" = "redir_host" -a "$cn_ip_route" = "已开启" ] && \
	iptables -t nat -A clash_out -m set --match-set cn_ip dst -j RETURN >/dev/null 2>&1 
	#仅允许本机流量
	for ip in 127.0.0.0/8 $local_ipv4;do 
		iptables -t nat -A clash_out -p tcp -s $ip -j REDIRECT --to-ports $redir_port
	done
	iptables -t nat -A OUTPUT -p tcp $ports -j clash_out
	#设置dns转发
	[ "$dns_no" != "已禁用" ] && {
	iptables -t nat -N clash_dns_out
	iptables -t nat -A clash_dns_out -m owner --gid-owner 7890 -j RETURN
	iptables -t nat -A clash_dns_out -p udp -s 127.0.0.0/8 -j REDIRECT --to $dns_port
	iptables -t nat -A OUTPUT -p udp --dport 53 -j clash_dns_out
	}
	#Docker转发
	ckcmd docker && {
		iptables -t nat -N clash_docker
		for ip in $host_ipv4 $reserve_ipv4;do #跳过目标保留地址及目标本机网段
			iptables -t nat -A clash_docker -d $ip -j RETURN
		done
		iptables -t nat -A clash_docker -p tcp -j REDIRECT --to-ports $redir_port
		iptables -t nat -A PREROUTING -p tcp -s 172.16.0.0/12 -j clash_docker
		[ "$dns_no" != "已禁用" ] && iptables -t nat -A PREROUTING -p udp --dport 53 -s 172.16.0.0/12 -j REDIRECT --to $dns_port
	}
}
start_tun(){
	modprobe tun &>/dev/null
	#允许流量
	iptables -I FORWARD -o utun -j ACCEPT
	iptables -I FORWARD -s 198.18.0.0/16 -o utun -j RETURN #防止回环
	ip6tables -I FORWARD -o utun -j ACCEPT > /dev/null 2>&1
	#屏蔽QUIC
	if [ "$quic_rj" = 已启用 ];then
		[ "$dns_mod" = "redir_host" -a "$cn_ip_route" = "已开启" ] && {
			set_cn_ip='-m set ! --match-set cn_ip dst'
			set_cn_ip6='-m set ! --match-set cn_ip6 dst'
		}
		iptables -I FORWARD -p udp --dport 443 -o utun -m comment --comment "ShellClash-QUIC-REJECT" $set_cn_ip -j REJECT >/dev/null 2>&1 
		ip6tables -I FORWARD -p udp --dport 443 -o utun -m comment --comment "ShellClash-QUIC-REJECT" $set_cn_ip6 -j REJECT >/dev/null 2>&1
	fi
	modprobe xt_mark &>/dev/null && {
		i=1
		while [ -z "$(ip route list |grep utun)" -a "$i" -le 29 ];do
			sleep 1
			i=$((i+1))
		done
		ip route add default dev utun table 100
		ip rule add fwmark $fwmark table 100
		#获取局域网host地址
		getlanip
		iptables -t mangle -N clash
		iptables -t mangle -A clash -p udp --dport 53 -j RETURN
		for ip in $host_ipv4 $reserve_ipv4;do #跳过目标保留地址及目标本机网段
			iptables -t mangle -A clash -d $ip -j RETURN
		done
		#防止回环
		iptables -t mangle -A clash -s 198.18.0.0/16 -j RETURN
		#绕过CN_IP
		[ "$dns_mod" = "redir_host" -a "$cn_ip_route" = "已开启" ] && \
		iptables -t mangle -A clash -m set --match-set cn_ip dst -j RETURN 2>/dev/null
		#局域网设备过滤
		if [ "$macfilter_type" = "白名单" -a -n "$(cat $clashdir/configs/mac)" ];then
			for mac in $(cat $clashdir/configs/mac); do #mac白名单
				iptables -t mangle -A clash -m mac --mac-source $mac -j MARK --set-mark $fwmark
			done
		else
			for mac in $(cat $clashdir/configs/mac); do #mac黑名单
				iptables -t mangle -A clash -m mac --mac-source $mac -j RETURN
			done
			#仅代理本机局域网网段流量
			for ip in $host_ipv4;do
				iptables -t mangle -A clash -s $ip -j MARK --set-mark $fwmark
			done
		fi
		iptables -t mangle -A PREROUTING -p udp $ports -j clash
		[ "$1" = "all" ] && iptables -t mangle -A PREROUTING -p tcp $ports -j clash
		
		#设置ipv6转发
		[ "$ipv6_redir" = "已开启" -a "$clashcore" = "clash.meta" ] && {
			ip -6 route add default dev utun table 101
			ip -6 rule add fwmark $fwmark table 101
			ip6tables -t mangle -N clashv6
			ip6tables -t mangle -A clashv6 -p udp --dport 53 -j RETURN
			for ip in $host_ipv6 $reserve_ipv6;do #跳过目标保留地址及目标本机网段
				ip6tables -t mangle -A clashv6 -d $ip -j RETURN
			done
			#绕过CN_IPV6
			[ "$dns_mod" = "redir_host" -a "$cn_ipv6_route" = "已开启" ] && \
			ip6tables -t mangle -A clashv6 -m set --match-set cn_ip6 dst -j RETURN 2>/dev/null
			#局域网设备过滤
			if [ "$macfilter_type" = "白名单" -a -n "$(cat $clashdir/configs/mac)" ];then
				for mac in $(cat $clashdir/configs/mac); do #mac白名单
					ip6tables -t mangle -A clashv6 -m mac --mac-source $mac -j MARK --set-mark $fwmark
				done
			else
				for mac in $(cat $clashdir/configs/mac); do #mac黑名单
					ip6tables -t mangle -A clashv6 -m mac --mac-source $mac -j RETURN
				done
				#仅代理本机局域网网段流量
				for ip in $host_ipv6;do
					ip6tables -t mangle -A clashv6 -s $ip -j MARK --set-mark $fwmark
				done					
			fi	
			ip6tables -t mangle -A PREROUTING -p udp $ports -j clashv6		
			[ "$1" = "all" ] && ip6tables -t mangle -A PREROUTING -p tcp $ports -j clashv6
		}
	} &
}
start_nft(){
	#获取局域网host地址
	getlanip
	[ "$common_ports" = "已开启" ] && PORTS=$(echo $multiport | sed 's/,/, /g')
	RESERVED_IP="$(echo $reserve_ipv4 | sed 's/ /, /g')"
	HOST_IP="$(echo $host_ipv4 | sed 's/ /, /g')"
	#设置策略路由
	ip rule add fwmark $fwmark table 100
	ip route add local default dev lo table 100
	[ "$redir_mod" = "Nft基础" ] && \
		nft add chain inet shellclash prerouting { type nat hook prerouting priority -100 \; }
	[ "$redir_mod" = "Nft混合" ] && {
		modprobe nft_tproxy &> /dev/null
		nft add chain inet shellclash prerouting { type filter hook prerouting priority 0 \; }
	}
	[ -n "$(echo $redir_mod|grep Nft)" ] && {
		#过滤局域网设备
		[ -n "$(cat $clashdir/configs/mac)" ] && {
			MAC=$(awk '{printf "%s, ",$1}' $clashdir/configs/mac)
			[ "$macfilter_type" = "黑名单" ] && \
				nft add rule inet shellclash prerouting ether saddr {$MAC} return || \
				nft add rule inet shellclash prerouting ether saddr != {$MAC} return
		}
		#过滤保留地址
		nft add rule inet shellclash prerouting ip daddr {$RESERVED_IP} return
		#仅代理本机局域网网段流量
		nft add rule inet shellclash prerouting ip saddr != {$HOST_IP} return
		#绕过CN-IP
		[ "$dns_mod" = "redir_host" -a "$cn_ip_route" = "已开启" -a -f $bindir/cn_ip.txt ] && {
			CN_IP=$(awk '{printf "%s, ",$1}' $bindir/cn_ip.txt)
			[ -n "$CN_IP" ] && nft add rule inet shellclash prerouting ip daddr {$CN_IP} return
		}
		#过滤常用端口
		[ -n "$PORTS" ] && nft add rule inet shellclash prerouting tcp dport != {$PORTS} ip daddr != {198.18.0.0/16} return
		#ipv6支持
		if [ "$ipv6_redir" = "已开启" ];then
			RESERVED_IP6="$(echo "$reserve_ipv6 $host_ipv6" | sed 's/ /, /g')"
			HOST_IP6="$(echo $host_ipv6 | sed 's/ /, /g')"
			ip -6 rule add fwmark $fwmark table 101 2> /dev/null
			ip -6 route add local ::/0 dev lo table 101 2> /dev/null
			#过滤保留地址及本机地址
			nft add rule inet shellclash prerouting ip6 daddr {$RESERVED_IP6} return
			#仅代理本机局域网网段流量
			nft add rule inet shellclash prerouting ip6 saddr != {$HOST_IP6} return
			#绕过CN_IPV6
			[ "$dns_mod" = "redir_host" -a "$cn_ipv6_route" = "已开启" -a -f $bindir/cn_ipv6.txt ] && {
				CN_IP6=$(awk '{printf "%s, ",$1}' $bindir/cn_ipv6.txt)
				[ -n "$CN_IP6" ] && nft add rule inet shellclash prerouting ip6 daddr {$CN_IP6} return
			}
		else
			nft add rule inet shellclash prerouting meta nfproto ipv6 return
		fi
		#透明路由
		[ "$redir_mod" = "Nft基础" ] && nft add rule inet shellclash prerouting meta l4proto tcp mark set $fwmark redirect to $redir_port
		[ "$redir_mod" = "Nft混合" ] && nft add rule inet shellclash prerouting meta l4proto {tcp, udp} mark set $fwmark tproxy to :$tproxy_port
	}
	#屏蔽QUIC
	[ "$quic_rj" = 已启用 ] && {
		nft add chain inet shellclash input { type filter hook input priority 0 \; }
		[ -n "$CN_IP" ] && nft add rule inet shellclash input ip daddr {$CN_IP} return
		[ -n "$CN_IP6" ] && nft add rule inet shellclash input ip6 daddr {$CN_IP6} return
		nft add rule inet shellclash input udp dport 443 reject comment 'ShellClash-QUIC-REJECT'
	}
	#代理本机(仅TCP)
	[ "$local_proxy" = "已开启" ] && [ "$local_type" = "nftables增强模式" ] && {
		#dns
		nft add chain inet shellclash dns_out { type nat hook output priority -100 \; }
		nft add rule inet shellclash dns_out meta skgid 7890 return && \
		nft add rule inet shellclash dns_out udp dport 53 redirect to $dns_port
		#output
		nft add chain inet shellclash output { type nat hook output priority -100 \; }
		nft add rule inet shellclash output meta skgid 7890 return && {
			[ -n "$PORTS" ] && nft add rule inet shellclash output tcp dport != {$PORTS} return
			nft add rule inet shellclash output ip daddr {$RESERVED_IP} return
			nft add rule inet shellclash output meta l4proto tcp mark set $fwmark redirect to $redir_port
		}
		#Docker
		type docker &>/dev/null && {
			nft add chain inet shellclash docker { type nat hook prerouting priority -100 \; }
			nft add rule inet shellclash docker ip saddr != {172.16.0.0/12} return #进代理docker网段
			nft add rule inet shellclash docker ip daddr {$RESERVED_IP} return #过滤保留地址
			nft add rule inet shellclash docker udp dport 53 redirect to $dns_port
			nft add rule inet shellclash docker meta l4proto tcp mark set $fwmark redirect to $redir_port
		}
	}
}
start_nft_dns(){
	nft add chain inet shellclash dns { type nat hook prerouting priority -100 \; }
	#过滤局域网设备
	[ -n "$(cat $clashdir/configs/mac)" ] && {
		MAC=$(awk '{printf "%s, ",$1}' $clashdir/configs/mac)
		[ "$macfilter_type" = "黑名单" ] && \
			nft add rule inet shellclash dns ether saddr {$MAC} return || \
			nft add rule inet shellclash dns ether saddr != {$MAC} return
	}
	nft add rule inet shellclash dns udp dport 53 redirect to ${dns_port}
	nft add rule inet shellclash dns tcp dport 53 redirect to ${dns_port}
}
start_wan(){
	#获取局域网host地址
	getlanip
	if [ "$public_support" = "已开启" ];then
		iptables -I INPUT -p tcp --dport $db_port -j ACCEPT
		ckcmd ip6tables && ip6tables -I INPUT -p tcp --dport $db_port -j ACCEPT 
	else
		#仅允许非公网设备访问面板
		for ip in $reserve_ipv4;do
			iptables -A INPUT -p tcp -s $ip --dport $db_port -j ACCEPT
		done
		iptables -A INPUT -p tcp --dport $db_port -j REJECT
		ckcmd ip6tables && ip6tables -A INPUT -p tcp --dport $db_port -j REJECT
	fi
	if [ "$public_mixport" = "已开启" ];then
		iptables -I INPUT -p tcp --dport $mix_port -j ACCEPT
		ckcmd ip6tables && ip6tables -I INPUT -p tcp --dport $mix_port -j ACCEPT 
	else
		#仅允许局域网设备访问混合端口
		for ip in $reserve_ipv4;do
			iptables -A INPUT -p tcp -s $ip --dport $mix_port -j ACCEPT
		done
		iptables -A INPUT -p tcp --dport $mix_port -j REJECT
		ckcmd ip6tables && ip6tables -A INPUT -p tcp --dport $mix_port -j REJECT 
	fi
	iptables -I INPUT -p tcp -d 127.0.0.1 -j ACCEPT #本机请求全放行
}
stop_firewall(){
	#获取局域网host地址
	getlanip
    #重置iptables相关规则
	ckcmd iptables && {
		#redir
		iptables -t nat -D PREROUTING -p tcp $ports -j clash 2> /dev/null
		iptables -t nat -D PREROUTING -p tcp -d 198.18.0.0/16 -j clash 2> /dev/null
		iptables -t nat -F clash 2> /dev/null
		iptables -t nat -X clash 2> /dev/null
		#dns
		iptables -t nat -D PREROUTING -p udp --dport 53 -j clash_dns 2> /dev/null
		iptables -t nat -F clash_dns 2> /dev/null
		iptables -t nat -X clash_dns 2> /dev/null
		#tun
		iptables -D FORWARD -o utun -j ACCEPT 2> /dev/null
		iptables -D FORWARD -s 198.18.0.0/16 -o utun -j RETURN 2> /dev/null
		#屏蔽QUIC
		[ "$dns_mod" = "redir_host" -a "$cn_ip_route" = "已开启" ] && set_cn_ip='-m set ! --match-set cn_ip dst'
		iptables -D INPUT -p udp --dport 443 -m comment --comment "ShellClash-QUIC-REJECT" $set_cn_ip -j REJECT 2> /dev/null
		iptables -D FORWARD -p udp --dport 443 -o utun -m comment --comment "ShellClash-QUIC-REJECT" $set_cn_ip -j REJECT 2> /dev/null
		#本机代理
		iptables -t nat -D OUTPUT -p tcp $ports -j clash_out 2> /dev/null
		iptables -t nat -F clash_out 2> /dev/null
		iptables -t nat -X clash_out 2> /dev/null	
		iptables -t nat -D OUTPUT -p udp --dport 53 -j clash_dns_out 2> /dev/null
		iptables -t nat -F clash_dns_out 2> /dev/null
		iptables -t nat -X clash_dns_out 2> /dev/null
		#docker
		iptables -t nat -F clash_docker 2> /dev/null
		iptables -t nat -X clash_docker 2> /dev/null
		iptables -t nat -D PREROUTING -p tcp -s 172.16.0.0/12 -j clash_docker 2> /dev/null
		iptables -t nat -D PREROUTING -p udp --dport 53 -s 172.16.0.0/12 -j REDIRECT --to $dns_port 2> /dev/null
		#TPROXY&tun
		iptables -t mangle -D PREROUTING -p tcp $ports -j clash 2> /dev/null
		iptables -t mangle -D PREROUTING -p udp $ports -j clash 2> /dev/null
		iptables -t mangle -D PREROUTING -p tcp -d 198.18.0.0/16 -j clash 2> /dev/null
		iptables -t mangle -D PREROUTING -p udp -d 198.18.0.0/16 -j clash 2> /dev/null
		iptables -t mangle -F clash 2> /dev/null
		iptables -t mangle -X clash 2> /dev/null
		#公网访问
		for ip in $host_ipv4 $local_ipv4 $reserve_ipv4;do
			iptables -D INPUT -p tcp -s $ip --dport $mix_port -j ACCEPT 2> /dev/null
			iptables -D INPUT -p tcp -s $ip --dport $db_port -j ACCEPT 2> /dev/null
		done
		iptables -D INPUT -p tcp -d 127.0.0.1 -j ACCEPT 2> /dev/null
		iptables -D INPUT -p tcp --dport $mix_port -j REJECT 2> /dev/null
		iptables -D INPUT -p tcp --dport $mix_port -j ACCEPT 2> /dev/null
		iptables -D INPUT -p tcp --dport $db_port -j REJECT 2> /dev/null
		iptables -D INPUT -p tcp --dport $db_port -j ACCEPT 2> /dev/null
	}
	#重置ipv6规则
	ckcmd ip6tables && {
		#redir
		ip6tables -t nat -D PREROUTING -p tcp $ports -j clashv6 2> /dev/null
		ip6tables -D INPUT -p udp --dport 53 -m comment --comment "ShellClash-IPV6_DNS-REJECT" -j REJECT 2> /dev/null
		ip6tables -t nat -F clashv6 2> /dev/null
		ip6tables -t nat -X clashv6 2> /dev/null
		#dns
		ip6tables -t nat -D PREROUTING -p udp --dport 53 -j clashv6_dns 2>/dev/null
		ip6tables -t nat -F clashv6_dns 2> /dev/null
		ip6tables -t nat -X clashv6_dns 2> /dev/null
		#tun
		ip6tables -D FORWARD -o utun -j ACCEPT 2> /dev/null
		ip6tables -D FORWARD -p udp --dport 443 -o utun -m comment --comment "ShellClash-QUIC-REJECT" -j REJECT >/dev/null 2>&1
		#屏蔽QUIC
		[ "$dns_mod" = "redir_host" -a "$cn_ipv6_route" = "已开启" ] && set_cn_ip6='-m set ! --match-set cn_ip6 dst'
		iptables -D INPUT -p udp --dport 443 -m comment --comment "ShellClash-QUIC-REJECT" $set_cn_ip6 -j REJECT 2> /dev/null
		iptables -D FORWARD -p udp --dport 443 -o utun -m comment --comment "ShellClash-QUIC-REJECT" $set_cn_ip6 -j REJECT 2> /dev/null
		#公网访问
		ip6tables -D INPUT -p tcp --dport $mix_port -j REJECT 2> /dev/null
		ip6tables -D INPUT -p tcp --dport $mix_port -j ACCEPT 2> /dev/null
		ip6tables -D INPUT -p tcp --dport $db_port -j REJECT 2> /dev/null	
		ip6tables -D INPUT -p tcp --dport $db_port -j ACCEPT 2> /dev/null
		#tproxy&tun
		ip6tables -t mangle -D PREROUTING -p tcp $ports -j clashv6 2> /dev/null
		ip6tables -t mangle -D PREROUTING -p udp $ports -j clashv6 2> /dev/null
		ip6tables -t mangle -F clashv6 2> /dev/null
		ip6tables -t mangle -X clashv6 2> /dev/null
		ip6tables -D INPUT -p udp --dport 443 -m comment --comment "ShellClash-QUIC-REJECT" $set_cn_ip -j REJECT 2> /dev/null
	}
	#清理ipset规则
	ipset destroy cn_ip >/dev/null 2>&1
	ipset destroy cn_ip6 >/dev/null 2>&1
	#移除dnsmasq转发规则
	[ "$dns_redir" = "已开启" ] && {
		uci del dhcp.@dnsmasq[-1].server >/dev/null 2>&1
		uci set dhcp.@dnsmasq[0].noresolv=0 2>/dev/null
		uci commit dhcp >/dev/null 2>&1
		/etc/init.d/dnsmasq restart >/dev/null 2>&1
	}
	#清理路由规则
	ip rule del fwmark $fwmark table 100  2> /dev/null
	ip route del local default dev lo table 100 2> /dev/null
	ip -6 rule del fwmark $fwmark table 101 2> /dev/null
	ip -6 route del local ::/0 dev lo table 101 2> /dev/null
	#重置nftables相关规则
	ckcmd nft && {
		nft flush table inet shellclash >/dev/null 2>&1
		nft delete table inet shellclash >/dev/null 2>&1
	}
}


TMPDIR=/tmp/singBox && [ ! -f $TMPDIR ] && mkdir -p $TMPDIR
start_time(){
    mkdir -p /tmp/singBox
    echo $(date +%s) > /tmp/singBox/start_time
}