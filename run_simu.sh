#!/bin/bash
export LD_LIBRARY_PATH=/usr/local/senseauto_local/3rdparty/linux_x86_64/lib:$LD_LIBRARY_PATH
printHelp() {
cat << HELP

Usage:
  $0 [-h|--help] [-s|--start] [-q|--quit] [-c|--check]
Example:
  $0 -s -n /log -p debug
Options:
  -h, --help                Show this help message.
  -s, --start               Start node.
  -q, --quit                Quit node.
  -c, --check               Check if node is up.
  -n, --log path            Specify path to redirect logs, works with -s
  -p, --log level           Specify log level, works with -s

HELP
return 0
}

Build_ALL(){
    
echo "build begin !!!!!!!!!!!!"
echo "start build senseauto-hozon-3rdparty "
cd senseauto-hozon-3rdparty
sudo rm -rf build && make hozon_deb_x86 && sudo dpkg -i build/*.deb
cd ..
echo "start build senseauto-hozon-framework-sdk "
cd senseauto-hozon-framework-sdk
sudo rm -rf build && make hozon_deb_x86 && sudo dpkg -i build/*.deb
cd ..
echo "start build senselotu-framework "
cd senselotu-framework
sudo rm -rf build && make hozon_deb_x86 && sudo dpkg -i build/*.deb
cd ..
echo "start build senseauto-simulation "
cd senseauto-hozon-simulation/topology
bash make_install_deb.sh
cd ../..
echo "start build senseauto-hozon-decision "
cd senseauto-hozon-decision/topology
bash make_install_deb.sh
cd ../..
echo "start build senseauto-hozon-simu-mcu "
cd senseauto-hozon-simu-mcu/topology
bash make_install_deb.sh
echo "build end !!!!!!!!!!!!"
}

Download_ALL(){
tmp_branch_download=${1}
tmp_manifest_xml=${2}
tmp_topic_download=${3}
tmp_visualizer_download=${4}
echo "start download simu !!!!!!!!!!!!  ${tmp_branch_download} ${tmp_manifest_xml}"
# init rep
echo "start repo initial !!!!!!!!!!!!"
repo init -u ssh://gerrit.senseauto.com/senseauto_manifest -b ${tmp_branch_download} -m ${tmp_manifest_xml} --repo-url=ssh://gerrit.senseauto.com:29418/senseauto_repo --repo-branch=develop --no-repo-verify
# sync code
echo "start sync code !!!!!!!!!!!!"
repo sync -d -c --force-sync --force-remove-dirty --prune -j8
if [ "$tmp_topic_download" != "" ];then
    # download topic
    echo "start download topic !!!!!!!!!!!! ${tmp_topic_download}"
    repo download-topic --only-manifest-branch ${tmp_topic_download}
fi
# download lfs
echo "start download topic !!!!!!!!!!!!"
repo forall -c "git lfs pull"
# download visualizer
echo "start download visualizer ${tmp_visualizer_download}  !!!!!!!!!!!!"
wget ${tmp_visualizer_download} 
tar -zxvf visualizer*.tar.gz
}

Start_ALL(){
echo "start run case !!!!!!!!!!!!11"
case_path=$1
#### 运行开始
# 启动decision节点
run_hozon_simu_decision_swc.sh -s > /tmp/log/run_simu_log.txt
# 启动mcu节点
run_hozon_simu_mcu_swc.sh -s > /tmp/log/run_simu_log.txt
# 启动simulator
simulator.sh -s ${case_path}

if [ -f "/tmp/simulator_log/simulation_report.json" ] && [ ! -f "/tmp/simulator_log/failed_reason.txt" ]; then
    echo "success !!!!!!!!!!!!"
    exit 0 
fi

if [ -f "/tmp/simulator_log/failed_reason.txt" ] && [ -f "analyze_simu_result.py" ] ; then
    echo "start analyze case result !!!!!!!!!!!!11"
    run_result=$(python3 analyze_simu_result.py)
    if [ "$run_result" == "success" ]; then
        echo "success !!!!!!!!!!!!"
        exit 0 
    else
        echo "faild !!!!!!!!!!!!"
        exit 1 
    fi
fi
}
Stop_ALL(){
    # 关闭仿真
simulator.sh -z
# 关闭mcu节点
run_hozon_simu_mcu_swc.sh -q
# 关闭decision节点
run_hozon_simu_decision_swc.sh -q
}
Start_Vis(){
./SENSETIME-VISUALIZER/runtime_swc/run_pc_decoder_and_hmi.sh -s
}

case $1 in
    -h|--help)
        printHelp;
        exit 0 ;;
    -s|--startAll)
        shift
        if [ $# -ge 1 ]; then
            agent_list_path=$1
            current_case_name=$agent_list_path
            echo "current case name is: $current_case_name"
            Start_ALL $current_case_name
        fi
        ;;
    -d|--download)
        manifest_xml="hozon_x86_nop.xml"
        branch_download="refs/changes/45/181045/17"
        topic_download=""
        visualizer_download="http://10.198.15.254:80/senseauto_packages/senseauto-hozon-nop/2023-10-25/feature_nnp-simulation-fit-ci_1620/visualizer_1620_hozon-nop_feature_nnp-simulation-fit-ci_c7c57e921.tar.gz"
        shift
        while [ $# -ge 2 ]
        do
            case $1 in
                -b) branch_download=${2}
                    ;;
                -m)
                    manifest_xml=${2}
                    ;;
                -t)
                    topic_download=${2}
                    ;;
                *)
                    printHelp;
                    exit 1 ;;
            esac
            shift 2
        done
        Download_ALL ${branch_download} ${manifest_xml} ${topic_download} ${visualizer_download};
        ;;
    -b|--build)
        Build_ALL;
        ;;
    -q|--quit)
        Stop_ALL;
        ;;
    -v|--visualizer)
        Start_Vis;
        ;;
    *)
        printHelp;
        exit 1
esac
