# 파일 위치로 이동
pushd $(dirname "$0")

# venv 활성화
python3 -m venv .venv
source .venv/bin/activate

# bash_kernel 설치
pip install bash_kernel 
python -m bash_kernel.install 

echo "다음 명령어를 실행하여 venv 활성화"
echo "source ./vault-example/.venv/bin/activate"