# Proxy sur Google Cloud

## Démarrer en arrière-plan avec nohup
`nohup node proxy.js > proxy.log 2>&1 &`

## Vérifier que le processus tourne
`ps aux | grep node`

`sudo netstat -tlnp | grep :3000`

## Testez l'accès local
`curl http://localhost:3000/proxy`
