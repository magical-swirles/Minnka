# Reducing Inter-Test Redundancy during Runtime Verification

## Appendix
See [appendix.pdf](appendix.pdf) for formative study's process.

## Projects and data
You can find the 52 projects and their revision that we evaluate [here](data/projects.csv), data [here](data/), and SHAs for evolution experiments [here](sha/).

## Repository structure
| Directory               | Purpose                                       |
| ------------------------| --------------------------------------------- |
| Docker                  | scripts to run our experiments in Docker      |
| data                    | raw data (see section above)                  |
| extensions              | Maven extensions to run Minnka                |
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

### Create redundant test suite
```sh
# Enter the following commands outside the Docker container and inside the current repository directory
cd Docker/experiments

# If you want to run experiment on all projects (this could take multiple days), then run the below command. If you only want to run experiment on one project (AAA-AA/basic-tools), then skip the command below.
cp projects-all.csv projects-collect.csv

bash buildmatrix_in_docker.sh projects-collect.csv $(pwd)/tsm-data
```

### Run Minnka
```sh
# Enter the following commands outside the Docker container and inside the current repository directory
cd Docker/experiments

# If you want to experiment on all projects (this could take multiple days), then run the below command. If you only want to run experiment on one project (AAA-AA/basic-tools), then skip the command below.
cp projects-all.csv projects-test.csv

bash single_experiment_in_docker.sh projects-test.csv $(pwd)/minnka-output $(pwd)/minnka-data
```
You can find the logs in the tsm-output/AAA-AA-basic-tools/output/logs directory.
