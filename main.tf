terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}


provider "docker" {
  host = "unix:///var/run/docker.sock"
}

resource "docker_network" "sabs_network" {
  name = "sabs_network"
}

resource "docker_image" "nginx" {
  name = "nginx:latest"
  keep_locally = false
}

resource "docker_image" "php-fpm" {
  name = "zhy7ne/8.1-fpm-alpine-z:2.0"
  keep_locally = false
}

resource "docker_image" "mysql" {
  name = "mysql:latest"
  keep_locally = false  
}

resource "docker_container" "load_balancer" {
  image = "nginx:latest"
  name = "lb"
  volumes {
    host_path = "/home/justine/configfiles/defaultlb.conf"
    container_path = "/etc/nginx/conf.d/default.conf"
  }
  ports {
    internal = 80
    external = 8080
  }
  networks_advanced {
    name = docker_network.sabs_network.name
  }
}

resource "docker_container" "server" {
  count = 2
  name = "server${count.index + 1}"
  image = "nginx:latest"
  volumes { 
    host_path = "/home/justine/configfiles/default${count.index + 1}.conf"
    container_path = "/etc/nginx/conf.d/default.conf"
  }	
  ports {
    internal = 80
    external = 8090 + count.index
  }
  networks_advanced {
    name = docker_network.sabs_network.name
  }
  depends_on = [docker_image.php-fpm, docker_image.nginx] 
}

resource "docker_container" "php-fpm" {
  count = 2
  name = "php-fpm${count.index + 1}"
  image = "zhy7ne/8.1-fpm-alpine-z:2.0"
  volumes {
    host_path = "/home/justine/configfiles/"
    container_path = "/var/www/html/"
  }
  volumes {
    host_path = "/home/justine/configfiles/index${count.index + 1}.php"
    container_path = "/var/www/html/index.php"
  }
  ports {
    internal = 9000
    external = 9001 + count.index
  }
  networks_advanced {
    name = docker_network.sabs_network.name
  }
  depends_on = [docker_image.php-fpm]
}

resource "docker_container" "mysql" {
  name = "dbserver1"
  image = "mysql:latest"
  env = [
    "MYSQL_ROOT_PASSWORD=password",
    "MYSQL_DATABASE=mydatabase",
    "MYSQL_USER=justine",
    "MYSQL_PASSWORD=password"
  ]
  ports {
    internal = 3306
    external = 33060
  }
  network_mode = docker_network.sabs_network.name
}
