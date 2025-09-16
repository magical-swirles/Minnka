#!/bin/bash
#
# Clone repository, and then run `mvn test` to collect tests name
# Usage: collect_tests.sh -r <repo> [-s <sha>] <extension-directory>
# Output: A tests.txt file in `projects/<project-name>` directory
#
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

source ${SCRIPT_DIR}/../experiments/constants.sh

cd ${SCRIPT_DIR}
PROJECT_DIR=${SCRIPT_DIR}/projects
mkdir -p ${PROJECT_DIR}
DISABLE_PUT=false

while getopts :r:s:u: opts; do
    case "${opts}" in
      r ) REPO="${OPTARG}" ;;
      s ) SHA="${OPTARG}" ;;
      u ) DISABLE_PUT="${OPTARG}" ;;
    esac
done
shift $((${OPTIND} - 1))
EXTENSION_DIR=$1
PROJECT_NAME=$(echo ${REPO} | tr / -)

if [[ -z "${REPO}" || -z "${EXTENSION_DIR}" ]]; then
  echo "Usage: ./collect_tests.sh -r <repo> [-s <sha>] <extension-directory>"
  exit 1
fi


if [[ ${REPO} != *"/"* ]]; then
  echo "Repo must be in the form <owner>/<project>"
  exit 1
fi


if [[ ! ${EXTENSION_DIR} = /* ]]; then
  EXTENSION_DIR=${SCRIPT_DIR}/${EXTENSION_DIR}
fi

function clone_repository() {
  if [[ ! -d "${PROJECT_DIR}/${PROJECT_NAME}" ]]; then
    git clone https://github.com/${REPO} "${PROJECT_DIR}/${PROJECT_NAME}"
    if [[ $? != 0 ]]; then
      exit 1
    fi

    # Checkout the commit
    pushd "${PROJECT_DIR}/${PROJECT_NAME}" &> /dev/null
    if [[ -n "${SHA}" ]]; then
      git checkout ${SHA}
    fi
    
    if [[ -f ${SCRIPT_DIR}/../experiments/treat_special.sh ]]; then
      # Run treat_special script
      bash ${SCRIPT_DIR}/../experiments/treat_special.sh ${PROJECT_DIR}/${PROJECT_NAME} ${PROJECT_NAME}
    fi
    popd &> /dev/null
  fi
}

function collect_tests() {
  pushd "${PROJECT_DIR}/${PROJECT_NAME}" &> /dev/null

  # Handle PUTs
  # Change @Parameters(name...) to @Parameters, so default name is {index}
  grep -rl --include="*.java" "@Parameterized.Parameters" | xargs grep -l --include="*.java" "org.junit.runners.Parameterized" | xargs sed -i -e 's/@Parameterized\.Parameters\(.*\)/@Parameterized.Parameters/g'
  grep -rl --include="*.java" "@Parameters" | xargs grep -l --include="*.java" "org.junit.runners.Parameterized" | xargs sed -i -e 's/@Parameters\(.*\)/@Parameters/g'
  grep -rl --include="pom.xml" "forkCount" | xargs sed -i -e 's/<forkCount>.*<\/forkCount>/<forkCount>1<\/forkCount>/g'
  
  # Set tmp directory to avoid conflict
  local tmp_dir="/tmp/tsm-tmp-${PROJECT_NAME}"
  rm -rf ${tmp_dir} && mkdir ${tmp_dir}

  export JUNIT_TEST_LISTENER=1
  time mvn -Djava.io.tmpdir=${tmp_dir} -Dmaven.repo.local="${PROJECT_DIR}/repo${REPO_SUFFIX}" -Dmaven.ext.class.path="${EXTENSION_DIR}/junit-extension-1.0.jar" ${SKIP} test
 
  if [[ $? != 0 ]]; then
    echo "Failed to collect tests (test failure)"
    exit 1
  fi
  
  # We need to add write permission because projects like apache/commons-io will create non-writable directories in tmp_dir
  chmod -R +w ${tmp_dir} && rm -rf ${tmp_dir}
  
  if [[ ! -f "tests.txt" ]]; then
    echo "Cannot use extension to get test cases. Checking surefire report..."
    
    if [[ ${IS_MMMP} == "true" ]]; then
      time mvn -Djava.io.tmpdir=${tmp_dir} -Dmaven.repo.local="${PROJECT_DIR}/repo${REPO_SUFFIX}" ${SKIP} -DskipTests install
      
      if [[ $? != 0 ]]; then
        echo "Failed to collect tests (install)"
        exit 1
      fi

      chmod -R +w ${tmp_dir} && rm -rf ${tmp_dir}
    fi
    
    bash ${SCRIPT_DIR}/../experiments/find-tests/find_tests_from_log.sh "${PROJECT_DIR}/${PROJECT_NAME}" ${PROJECT_NAME}
    
    if [[ ! -f "tests.txt" ]]; then
      echo "Failed to collect tests (no tests.txt)"
      exit 1
    fi
  fi
  
  # Remove PUT
  if [[ ${DISABLE_PUT} == "true" ]]; then
    cut -d '[' -f 1 tests.txt > tests.tmp.txt
    cat tests.tmp.txt | sort | uniq > tests.txt
  else
    cat tests.txt | sort | uniq > tests.tmp.txt
    mv tests.tmp.txt tests.txt
  fi

  cp -r target/surefire-reports initial-surefire-reports
  popd &> /dev/null
}

clone_repository
collect_tests
