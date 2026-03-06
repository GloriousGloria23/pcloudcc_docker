# pcloudcc_docker
<p>
<a href="https://github.com/jlloyola/pcloudcc_docker/actions"><img alt="Actions Status" src="https://github.com/jlloyola/pcloudcc_docker/actions/workflows/docker-image.yml/badge.svg"></a>
<a href="https://hub.docker.com/r/jloyola/pcloudcc"><img alt="Docker pulls" src="https://img.shields.io/docker/pulls/jloyola/pcloudcc"></a>
<a href="https://github.com/jlloyola/pcloudcc_docker/blob/main/LICENSE"><img alt="License: GPL-3.0" src="https://img.shields.io/github/license/jlloyola/pcloudcc_docker"></a>
</p>

This repo defines a Dockerfile to build the
[pcloud console client](https://github.com/pcloudcom/console-client)
from source and run it inside a container.  

The container exposes your pcloud drive in a location of your
choice. It runs using non-root `uid`:`gid` to properly handle
file permissions and allow seamless file transfers between the host, the container, and pcloud.  
This image includes PR [#163](https://github.com/pcloudcom/console-client/pull/163)
to enable one-time password multi-factor authentication.

## Building the Image

You can build the image using either the provided `Makefile` or standard `docker build`.

### Using Makefile
The `Makefile` simplifies the build process and sets default tags.
```bash
make build
```
This will build the image as `jloyola/pcloudcc:dev`. You can override variables if needed:
```bash
make build REPOSITORY=myuser/pcloudcc LABEL=latest
```

### Using Docker Build
```bash
docker build -t jloyola/pcloudcc:dev .
```

## Setup instructions
It is recommended to use a compose file to simplify setup.  
Make sure you have docker installed. Refer to https://docs.docker.com/engine/install/

### 1. Obtain your user and group ID
You can get them from the command line. For example
```bash
% id -u
1000
% id -g
1000
```
### 2. Create a `.env` file
Enter the relevant information for your setup:
| Variable           | Purpose                                    | Sample Value          |
|----------------    |--------------------------------------------|-----------------------|
|PCLOUD_IMAGE        |Image version                               |jloyola/pcloudcc:dev   |
|PCLOUD_DRIVE        |Host directory where pcloud will be mounted |/home/user/pCloudDrive |
|PCLOUD_USERNAME     |Your pcloud username                        |example@example.com    |
|PCLOUD_PASSWORD     |Your pcloud password (for headless login)   |********               |
|PCLOUD_UID          |Your host user id (obtained above)          |1000                   |
|PCLOUD_GID          |Your host group id (obtained above)         |1000                   |
|PCLOUD_SAVE_PASSWORD|Save password in cache volume               |1                      |

Example `.env` file:  
```ini
PCLOUD_IMAGE=jloyola/pcloudcc:dev
PCLOUD_DRIVE=/home/user/pCloudDrive
PCLOUD_USERNAME=example@example.com
PCLOUD_PASSWORD=your_secret_password
PCLOUD_UID=1000
PCLOUD_GID=1000
PCLOUD_SAVE_PASSWORD=1
```

### 3. Create the pcloud directory on the host
```bash
mkdir -p <PCLOUD_DRIVE>
```
`<PCLOUD_DRIVE>` corresponds to the same directory you specified in the `.env`

### 4. Initial run and Login
> [!IMPORTANT]
> For the **very first run**, it is highly recommended to use `make init` or `docker run -it`. `docker compose up -d` starts the container in the background, which makes it difficult to see and respond to the initial password prompt.

1. Start the container interactively (First time only):
   ```bash
   make init
   ```
   **OR**
   ```bash
   docker run --rm -it \
     -e PCLOUD_USERNAME=user@example.com \
     -v pcloud_cache:/home/pcloud/.pcloud \
     --device /dev/fuse --cap-add SYS_ADMIN \
     jloyola/pcloudcc:dev
   ```

2. Once you see `status is READY`, you can stop the container with `Ctrl+C` and then start it in the background using Compose:
   ```bash
   docker compose up -d
   ```

3. If you ever need to re-login interactively (e.g., after a password change or `BAD_LOGIN_TOKEN` error):
   - Attach to the running container: `docker attach <container_id>`
   - If it's "stuck" at `BAD_LOGIN_TOKEN`, you may need to force a session reset.

### Force Session Reset
If you are getting persistent `BAD_LOGIN_TOKEN` errors or the container seems "stuck" after a failed login, you can force a fresh login by setting `PCLOUD_CLEAN_SESSION=1` in your `.env` and restarting the container:
```bash
docker compose up -d --force-recreate
```
*Note: Don't forget to set it back to `0` once you've successfully logged in.*

### 5. Access your pcloud drive
You can now access your pcloud drive from your host machine
at the location specified in your `.env` file.

## Troubleshooting
When stopping the container, the mount point can get stuck.  
Run the following command to fix it
```bash
% fusermount -uz <PCLOUD_DRIVE>
```
`<PCLOUD_DRIVE>` corresponds to the same directory you specified in the `.env`.  

## Acknowledgments
The code in this repo was inspired by the work from:
* zcalusic: https://github.com/zcalusic/dockerfiles/tree/master/pcloud
* abraunegg: https://github.com/abraunegg/onedrive
