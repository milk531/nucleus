#!/usr/bin/env bash

# This script shows how to build the Docker image and push it to ECR to be ready for use
# by SageMaker.

# The argument to this script is the image name. This will be used as the image on the local
# machine and combined with the account and region to form the repository name for ECR.


image=$TARGET_IMAGE

function help() {
    echo "$0 help|build|test|cleanc|cleani|rmc"
}

function build() {
    if [ "$image" == "" ]
    then
        echo "No build name is setup."
        exit 1
    fi
    # Get the account number associated with the current IAM credentials
    account=$(aws sts get-caller-identity --query Account --output text)

    if [ $? -ne 0 ]
    then
        exit 255
    fi


    # Get the region defined in the current configuration (default to us-east-1 if none defined)
    region=$(aws configure get region)
    region=${region:-us-east-1}


    fullname="${account}.dkr.ecr.${region}.amazonaws.com/${image}:latest"

    # If the repository doesn't exist in ECR, create it.

    aws ecr describe-repositories --repository-names "${image}" > /dev/null 2>&1

    if [ $? -ne 0 ]
    then
        aws ecr create-repository --repository-name "${image}" > /dev/null
    fi

    # Get the login command from ECR and execute it directly
    aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $account.dkr.ecr.$region.amazonaws.com

    # Get the login command from ECR in order to pull down the SageMaker PyTorch image
    aws ecr get-login-password --region $region | docker login --username AWS --password-stdin 763104351884.dkr.ecr.$region.amazonaws.com

    # Build the docker image locally with the image name and then push it to ECR
    # with the full name.

    docker build -f nucleus.Dockerfile  -t ${image} . --build-arg REGION=${region}

    docker tag ${image} ${fullname}

    docker push ${fullname}

}

function test() {
    if [ "$image" == "" ]
    then
        echo "No build name is setup."
        exit 1
    fi
    docker run -it --rm -p 8080:8080 ${image}
}

function rm_all() {
    docker rm $(docker ps -aq)
}

function clean_image() {
    docker image prune
}
function clean_container() {
    docker container prune
}


if [ "$1" == "" ]; then
    build
elif [ "$1" == "help" ];then
    help
elif [ "$1" == "build" ];then
    build
elif [ "$1" == "test" ];then
    test
elif [ "$1" == "rmc" ];then
    rm_all
elif [ "$1" == "cleani" ];then
    clean_image
elif [ "$1" == "cleanc" ];then
    clean_container
else
    help
fi




