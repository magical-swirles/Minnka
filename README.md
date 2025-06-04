# Test-Suite Reduction for Runtime Verification

## Appendix
See [appendix.pdf](appendix.pdf) for RQ3's detailed results.

## Projects and data
You can find the 50 projects and their revision that we evaluate [here](data/projects.csv), and SHAs for evolution experiments [here](sha/). [This directory](data/evolution) contains the raw data from the software evolution experiments.

## Repository structure
| Directory               | Purpose                                       |
| ------------------------| --------------------------------------------- |
| Docker                  | scripts to run our experiments in Docker      |
| data                    | raw data (see section above)                  |
| extensions              | a Maven extension to run Minnka               |
| mop                     | the set of JavaMOP specifications that we use |
| rvtsm-maven-plugin      | Minnka's Maven plugin                         |
| scripts & experiments   | our experimental infrastructure               |
| sha                     | SHAs for evolution experiments                |


## Usage
### Prerequisites:
- A x86-64 architecture machine
- Ubuntu 22.04
- [Docker](https://docs.docker.com/get-docker/)
### Setup
First, you need to build a Docker image. Run the following commands in the terminal.
```sh
docker build -f Docker/Dockerfile . --tag=minnka
docker run -it --rm minnka
./setup.sh  # run this command in Docker container
```
Then, run the following command in a new terminal window.
```sh
docker ps  # get container id
docker commit <container-id> minnka:latest
# You can now close the previous terminal window by entering `exit`
```

### Run single revision experiments (RQ1/RQ2/RQ3)
```sh
# Enter the following commands outside the Docker container and inside the current repository directory
cd Docker/experiments

# If you want to run single version experiment on all projects (this could take multiple days), then run the below command. If you only want to run experiment on one project (albfernandez/javadbf), then skip the command below.
cp projects-all.csv projects.csv

# Run experiment: for one program version
bash plugin_in_docker.sh -t "none,time" -l "greedy,ge,gre,hgs" -c "no-track,track,no-rv" projects.csv output
```

The above commands will generate an output directory. The output directory contains one sub-directory per project. The `output/<project-name>/project/logs` directory contains logs from multiple runs. The format of the file name is `<equivalence>-<time-breaker>-<algorithm>-<mode>.txt`, where `<equivalence>` is the notion of equivalence, `<time-breaker>` indicates whether a time breaker is used (none or time), `<algorithm>` is the reduction algorithm (greedy, ge, gre, or hgs), and `<mode>` specifies whether RV is used (no-rv, no-track (JavaMOP), or track (TraceMOP)).

### Run evolution related experiments (RQ4/RQ5)
```sh
# Enter the following commands outside the Docker container and inside the current repository directory
cd Docker/experiments

# If you want to run single version experiment on all projects (this could take multiple days), then run the below command. If you only want to run experiment on one project (albfernandez/javadbf), then skip the command below.
cp projects-evolution-all.csv projects-evolution.csv

# Run experiment: for one program version
bash evolution_in_docker.sh projects-evolution.csv output-evolution
```
The above commands will generate an output directory. The output directory contains one sub-directory per project. The file `output-evolution/<project-name>/project/logs/results.csv` contains the following csv (times are in ms):
```
sha,test_time,test_status,minnka_time,minnka_status,minnka_violations,minnka_emop_time,minnka_emop_status,minnka_emop_violations,minnka_imop_time,minnka_imop_status,minnka_imop_violations,redundant_test_time,redundant_test_status,minnka_partial_time,minnka_partial_status,minnka_partial_violations,redundant_partial_test_time,redundant_partial_test_status,all_javamop_time,all_javamop_status,all_javamop_violations,all_emop_time,all_emop_status,all_emop_violations,all_imop_time,all_imop_status,all_imop_violations,all_rts_javamop_time,all_rts_javamop_status,all_rts_javamop_violations
```

### Use coverage as test requirements (RQ5)
```sh
# Enter the following commands outside the Docker container and inside the current repository directory
cd Docker/experiments

# If you want to run single version experiment on all projects (this could take multiple days), then run the below command. If you only want to run experiment on one project (albfernandez/javadbf), then skip the command below.
cp projects-codecov-all.csv projects-codecov.csv

# Run experiment: for one program version
bash coverage_in_docker.sh projects-codecov.csv output-codecov
```
The above commands will generate an output directory. The output directory contains one sub-directory per project. The `output-codecov/<project-name>/project/logs` directory contains three logs:

- `coverage-no-track-log.txt`: Reduced test suite with JavaMOP
- `coverage-track-log.txt`: Reduced test suite with TraceMOP
- `coverage-redundant-no-rv-log.txt`: Redundant test suite without RV
