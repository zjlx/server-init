#! /bin/bash
# Description: This is a script to depoly some tools
# Version: 1.0
# Date: 2018-10-23


# Whether the script is run by root
 R_E(){
	echo -e "\e[1;31m$1\e[0m"
 }
 G_E(){
	echo -e "\e[1;32m$1\e[0m"
 }
 Y_E(){
	echo -e "\e[1;33m$1\e[0m"
 }
 B_E(){
	echo -e "\e[1;34m$1\e[0m"
 }
 wk_dir="/usr/src"
 ngx_loc="/usr/local/nginx"
 ac_loc="/usr/local/acme"
 if [ $(id -u) != "0" ]; then
	R_E "Sorry, this script must run by root. Please change to root to run this script!"
	exit 1
 fi
 Y_E "[+] Install new kernel..."
 rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
 rpm -Uvh https://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm
 yum -y --enablerepo=elrepo-kernel install kernel-ml
 grub2-set-default 0
 echo 'net.core.default_qdisc=fq' | sudo tee -a /etc/sysctl.conf
 echo 'net.ipv4.tcp_congestion_control=bbr' | sudo tee -a /etc/sysctl.conf
 sysctl -p
 yum install -y epel-release
 yum install -y https://centos7.iuscommunity.org/ius-release.rpm
 yum makecache
 yum install -y gcc curl gcc-c++ gcc-g77 git2u python36u python36u-devel python36u-pip patch net-tools lsof vim zlib zlib-devel libatomic pcre pcre-devel zip unzip google-perftools google-perftools-devel GeoIP-devel gd gd-devel

 # Download software
 if grep -Eqi "www" /etc/passwd; then
 	G_E "www has been added."
 else
 	useradd  -s /sbin/nologin www
 fi
 if [ -s /usr/local/nginx/conf/nginx.conf ]; then
 	G_E "nginx has been installed, nothing to do."
	exit 1
 else
 	cd ${wk_dir}
 	wget https://nginx.org/download/nginx-1.15.5.tar.gz
 	wget https://www.openssl.org/source/openssl-1.1.1.tar.gz
 	tar zxf nginx-1.15.5.tar.gz
 	tar zxf openssl-1.1.1.tar.gz
 	curl https://raw.githubusercontent.com/kn007/patch/43f2d869b209756b442cfbfa861d653d993f16fe/nginx.patch >> nginx.patch
 	curl https://raw.githubusercontent.com/hakasenyang/openssl-patch/master/nginx_strict-sni.patch >> nginx_strict-sni.patch
 	curl https://raw.githubusercontent.com/hakasenyang/openssl-patch/master/openssl-equal-1.1.1_ciphers.patch >> openssl-equal-1.1.1_ciphers.patch
 	curl https://raw.githubusercontent.com/hakasenyang/openssl-patch/master/openssl-1.1.1-chacha_draft.patch >> openssl-1.1.1-chacha_draft.patch
 	git clone https://github.com/wandenberg/nginx-sorted-querystring-module.git
 	git clone https://github.com/yaoweibin/ngx_http_substitutions_filter_module.git
 	git clone https://github.com/eustas/ngx_brotli.git
 	cd ngx_brotli
 	git submodule update --init
 	cd ../openssl-1.1.1
 	patch -p1 < ../openssl-equal-1.1.1_ciphers.patch
 	patch -p1 < ../openssl-1.1.1-chacha_draft.patch
 	cd ../nginx-1.15.5
 	patch -p1 < ../nginx.patch
 	patch -p1 < ../nginx_strict-sni.patch
 	mkdir -p ${ngx_loc}/temp
 	mkdir -p ${ngx_loc}/conf/vhosts
 	./configure \
 	--user=www \
 	--group=www \
 	--http-client-body-temp-path=${ngx_loc}/temp/body \
 	--http-fastcgi-temp-path=${ngx_loc}/temp/fastcgi\
 	--http-proxy-temp-path=${ngx_loc}/temp/proxy \
 	--http-scgi-temp-path=${ngx_loc}/temp/scgi \
 	--http-uwsgi-temp-path=${ngx_loc}/temp/uwsgi \
 	--with-threads \
 	--with-file-aio \
 	--with-pcre-jit \
 	--with-stream \
 	--with-stream_ssl_module \
 	--with-stream_realip_module \
 	--with-stream_ssl_preread_module \
 	--with-google_perftools_module \
 	--with-http_slice_module \
 	--with-http_geoip_module \
 	--with-http_v2_module \
 	--with-http_v2_hpack_enc \
 	--with-http_spdy_module \
 	--with-http_sub_module \
 	--with-http_flv_module \
 	--with-http_mp4_module \
 	--with-http_gunzip_module \
 	--with-http_realip_module \
 	--with-http_addition_module \
 	--with-http_gzip_static_module \
 	--with-http_degradation_module \
 	--with-http_secure_link_module \
 	--with-http_stub_status_module \
 	--with-http_random_index_module \
 	--with-http_auth_request_module \
 	--with-openssl=../openssl-1.1.1 \
 	--add-module=../ngx_brotli \
 	--add-module=../nginx-sorted-querystring-module \
 	--add-module=../ngx_http_substitutions_filter_module 
 	make
 	make install
 	mv ${ngx_loc}/conf/nginx.conf ${ngx_loc}/conf/nginx_bak
	cat>${ngx_loc}/conf/nginx.conf<<EOF
user  www;
worker_processes  1;
error_log  logs/error.log;
pid        logs/nginx.pid;
events {
	worker_connections  1024;
}		
http {
	include				mime.types;
    default_type		application/octet-stream;
    server_tokens		off;
    charset				UTF-8;
    sendfile			on;
    tcp_nopush			on;
    tcp_nodelay			on;
    keepalive_timeout	60;
    brotli				on;			
    brotli_static 		on;
    brotli_comp_level 	6;
    brotli_buffers		32 8k;
    gzip				on;
    gzip_vary			on;
    gzip_comp_level		6;
    gzip_buffers		16 8k;
    gzip_min_length		1000;
    gzip_proxied		any;
   	gzip_disable		"msie6";
    gzip_http_version	1.0;
    gzip_types			text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript application/javascript image/svg+xml;
    include				vhosts/*.conf;
}
EOF
	cat>${ngx_loc}/conf/vhosts/default.conf<<EOF
server{
		listen          80;
		server_name     localhost;
		root			html;
		index			index.html;
}

EOF
 	${ngx_loc}/sbin/nginx -t
 	if [ $? != "0" ]; then
 		R_E "Failed to install nginx, please check log for details!"
 		exit 1
 	else
 		G_E "Nginx installed successful!"
 		cat>/lib/systemd/system/nginx.service<<EOF
[Unit]
	Description=Nginx Process Manager
	After=network.target
[Service]
	Type=forking
	ExecStart=/usr/local/nginx/sbin/nginx -c /usr/local/nginx/conf/nginx.conf
	ExecReload=/usr/local/nginx/sbin/nginx -s reload
	ExecStop=/usr/local/nginx/sbin/nginx -s quit
	PrivateTmp=false
[Install]
	WantedBy=multi-user.target
EOF
 	fi
 	systemctl enable nginx 
 	systemctl start nginx
 fi

 # install acme.sh to get certificate
 cd ${wk_dir}
 if [ -d ${ac_loc} ]; then
 	G_E "Acme.sh has been installed, nothing to do!"
 else
 	git clone https://github.com/Neilpang/acme.sh.git
 	cd acme.sh
 	./acme.sh --install --home=${ac_loc} --cert-home=${ac_loc}/certs --config-home=${ac_loc}/config
 fi
 	reboot




