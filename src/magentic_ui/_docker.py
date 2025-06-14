import docker
import os
import sys
from docker.errors import DockerException, ImageNotFound
from pathlib import Path
import logging

_PACKAGE_DIR = os.path.dirname(os.path.abspath(__file__))
VNC_BROWSER_IMAGE = "magentic-ui-vnc-browser"
PYTHON_IMAGE = "magentic-ui-python-env"

VNC_BROWSER_BUILD_CONTEXT = "magentic-ui-browser-docker"
PYTHON_BUILD_CONTEXT = "magentic-ui-python-env"


def check_docker_running() -> bool:
    try:
        client = docker.from_env()
        client.ping()  # type: ignore
        return True
    except Exception as e:
        # Handle macOS Docker Desktop socket location
        logging.debug(f"Initial Docker connection failed with: {type(e).__name__}: {e}")
        if "No such file or directory" in str(e) or isinstance(e, (DockerException, ConnectionError, FileNotFoundError)):
            try:
                # Try common macOS Docker Desktop socket locations
                docker_socket_paths = [
                    os.path.expanduser("~/.docker/run/docker.sock"),
                    os.path.expanduser("~/.docker/desktop/docker.sock"),
                    "/var/run/docker.sock"
                ]
                
                for socket_path in docker_socket_paths:
                    if os.path.exists(socket_path):
                        # Set DOCKER_HOST environment variable temporarily
                        original_docker_host = os.environ.get('DOCKER_HOST')
                        os.environ['DOCKER_HOST'] = f'unix://{socket_path}'
                        try:
                            client = docker.from_env()
                            client.ping()  # type: ignore
                            logging.debug(f"Successfully connected using socket: {socket_path}")
                            return True
                        except Exception as inner_e:
                            logging.debug(f"Failed to connect with socket {socket_path}: {inner_e}")
                            # Restore original DOCKER_HOST if this path doesn't work
                            if original_docker_host is not None:
                                os.environ['DOCKER_HOST'] = original_docker_host
                            elif 'DOCKER_HOST' in os.environ:
                                del os.environ['DOCKER_HOST']
                            continue
            except Exception as retry_e:
                logging.error(f"Failed to connect to Docker even after trying alternative socket paths: {retry_e}")
        else:
            logging.debug(f"Non-socket related Docker error: {type(e).__name__}: {e}")
        
        return False


def build_image(
    image_name: str, build_context: str, client: docker.DockerClient
) -> None:
    for segment in client.api.build(
        path=build_context,
        dockerfile="Dockerfile",
        rm=True,
        tag=image_name,
        decode=True,
    ):
        if "stream" in segment:
            lines = segment["stream"].splitlines()
            for line in lines:
                if line:
                    sys.stdout.write(line + "\n")
                    sys.stdout.flush()


def check_docker_image(image_name: str, client: docker.DockerClient) -> bool:
    try:
        client.images.get(image_name)
        return True
    except ImageNotFound:
        return False


def build_browser_image(client: docker.DockerClient | None = None) -> None:
    if client is None:
        client = docker.from_env()
    client = docker.from_env()
    build_image(
        VNC_BROWSER_IMAGE + ":latest",
        os.path.join(_PACKAGE_DIR, "docker", VNC_BROWSER_BUILD_CONTEXT),
        client,
    )


def build_python_image(client: docker.DockerClient | None = None) -> None:
    if client is None:
        client = docker.from_env()
    client = docker.from_env()
    build_image(
        PYTHON_IMAGE + ":latest",
        os.path.join(_PACKAGE_DIR, "docker", PYTHON_BUILD_CONTEXT),
        client,
    )


def check_docker_access():
    try:
        client = docker.from_env()
        client.ping()  # type: ignore
        return True
    except DockerException as e:
        logging.error(
            f"Error {e}: Cannot access Docker. Please refer to the TROUBLESHOOTING.md document for possible solutions."
        )
        return False


def check_browser_image(client: docker.DockerClient | None = None) -> bool:
    if not check_docker_access():
        return False
    if client is None:
        client = docker.from_env()
    client = docker.from_env()
    return check_docker_image(VNC_BROWSER_IMAGE, client)


def check_python_image(client: docker.DockerClient | None = None) -> bool:
    if not check_docker_access():
        return False
    if client is None:
        client = docker.from_env()
    client = docker.from_env()
    return check_docker_image(PYTHON_IMAGE, client)
