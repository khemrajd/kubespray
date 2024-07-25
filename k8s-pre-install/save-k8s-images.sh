CURRENT_DIR=$(cd $(dirname $0); pwd)
KUBESPRAYDIR="${CURRENT_DIR}/../kubespray"
IMAGETEMPLATE="${1:-${CURRENT_DIR}/kube.images.template}"
IMAGEFILE="${CURRENT_DIR}/kube.images"
CNTR_CMD="${2:-/usr/local/bin/nerdctl}"

function _error(){
  echo "ERROR: [$@]"
  exit 1
}

rm -f ${IMAGEFILE}
cp ${IMAGETEMPLATE} ${IMAGEFILE}
#kube_version
kube_version=$(sed -n "s/kube_version: //p" \
${KUBESPRAYDIR}/roles/kubespray-defaults/defaults/main/main.yml| tr -d '"')
echo "kube_version=${kube_version}"
[ -z kube_version ] && _error "fecth kube_version"
sed -i "s/__kube_version__/${kube_version}/g" ${IMAGEFILE}

#update calico_version
calico_version=$(sed -n "s/calico_version: //p" \
${KUBESPRAYDIR}/roles/kubespray-defaults/defaults/main/download.yml| tr -d '"')
echo "calico_version=${calico_version}"
sed -i "s/__calico_version__/${calico_version}/g" ${IMAGEFILE}

#update metrics_server_version
metrics_server_version=$(sed -n "s/metrics_server_version: //p" \
${KUBESPRAYDIR}/roles/kubespray-defaults/defaults/main/download.yml | tr -d '"')
echo "metrics_server_version=${metrics_server_version}"
sed -i "s/__metrics_server_version__/${metrics_server_version}/g" ${IMAGEFILE}

#update cert_manager_version
cert_manager_version=$(sed -n "s/cert_manager_version: //p" \
${KUBESPRAYDIR}/roles/kubespray-defaults/defaults/main/download.yml | tr -d '"')
echo "cert_manager_version=${cert_manager_version}"
sed -i "s/__cert_manager_version__/${cert_manager_version}/g" ${IMAGEFILE}

#cpa/cluster-proportional-autoscaler
dnsautoscaler_version=$(sed -n "s/dnsautoscaler_version: //p" \
${KUBESPRAYDIR}/roles/kubespray-defaults/defaults/main/download.yml| tr -d '"')
echo "dnsautoscaler_version=${dnsautoscaler_version}"
sed -i "s/__dnsautoscaler_version__/${dnsautoscaler_version}/g" ${IMAGEFILE}

metallb_version=$(sed -n "s/metallb_version: //p" \
		${KUBESPRAYDIR}/roles/kubespray-defaults/defaults/main/download.yml| tr -d '"')
echo "metallb_version=${metallb_version}"
sed -i "s/__metallb_version__/${metallb_version}/g" ${IMAGEFILE}

multus_version=$(sed -n "s/multus_version: //p" \
		${KUBESPRAYDIR}/roles/kubespray-defaults/defaults/main/download.yml| tr -d '"')
echo "multus_version=${multus_version}"
sed -i "s/__multus_version__/${multus_version}/g" ${IMAGEFILE}

#dns/k8s-dns-node-cache
nodelocaldns_version=$(sed -n "s/nodelocaldns_version: //p" \
		${KUBESPRAYDIR}/roles/kubespray-defaults/defaults/main/download.yml| tr -d '"')
echo "nodelocaldns_version=${nodelocaldns_version}"
sed -i "s/__nodelocaldns_version__/${nodelocaldns_version}/g" ${IMAGEFILE}

#
coredns_version=$(sed -n "s/coredns_version: //p" \
		${KUBESPRAYDIR}/roles/kubespray-defaults/defaults/main/download.yml| tr -d '"')
echo "coredns_version=${coredns_version}"
#sed -i "s/__coredns_version__/${coredns_version}/g" ${IMAGEFILE}

## Pull and save ${IMAGEFILE} listed in file ${IMAGEFILE}
IMAGETARDIR="${CURRENT_DIR}/k8s-${kube_version}-offline-files/images/"
mkdir -p ${IMAGETARDIR}
while read -r image; do
    [[ "$image" =~ ^#.*$ ]] && continue #Ignore comment
    [[ "$image" =~ ^[[:space:]]*$ ]] && continue #Ignore empty line
    echo "Pulling image [${image}]"
    ${CNTR_CMD} pull ${image}
    [[ 0 -ne $? ]] && _error "Failed to pull ${image}"
    img_tar="$(echo $image | sed 's@/@_@g' | sed 's@:@_@g').tar"
    echo "Saving image [${image}] ==> [${img_tar}]"
    ${CNTR_CMD} -n k8s.io image save -o ${IMAGETARDIR}/${img_tar} ${image}
    [[ 0 -ne $? ]] && _error "Failed to save ${image}"
done < "${IMAGEFILE}"

