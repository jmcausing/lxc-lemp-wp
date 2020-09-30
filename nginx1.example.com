server {
    listen 80 proxy_protocol;
    listen [::]:80 proxy_protocol;

    # server_name nginx1.example.com;

    location / {
            # This is to fix the mixed-content issue
            proxy_set_header X-Forwarded-Proto $scheme;
                        
            proxy_set_header Host $host; 
            proxy_set_header X-Real-IP $remote_addr;
            # proxy_pass http://nginx1.lxd; #nginx1 is the name of the lxd
    }

    real_ip_header proxy_protocol;
    set_real_ip_from 127.0.0.1;
}
