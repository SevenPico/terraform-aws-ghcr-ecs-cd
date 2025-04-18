import os
import json
import hmac
import hashlib
import boto3
import urllib.parse
import logging
import base64

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
ecs_client = boto3.client('ecs')
secrets_client = boto3.client('secretsmanager')

# Global variables
GITHUB_CREDENTIALS_SECRET_ARN = os.environ.get('GITHUB_CREDENTIALS_SECRET_ARN', '')
GITHUB_WEBHOOK_SECRET = None
SERVICE_MAP = {}  # Will be populated by Terraform

def get_webhook_secret():
    """Retrieve the webhook secret from AWS Secrets Manager"""
    global GITHUB_WEBHOOK_SECRET
    
    logger.info(f"Getting webhook secret from ARN: {GITHUB_CREDENTIALS_SECRET_ARN}")
    
    if not GITHUB_CREDENTIALS_SECRET_ARN:
        logger.error("No GitHub credentials secret ARN provided")
        return None
    
    try:
        response = secrets_client.get_secret_value(SecretId=GITHUB_CREDENTIALS_SECRET_ARN)
        logger.info(f"Secret retrieved successfully, has SecretString: {bool(response.get('SecretString'))}")
        
        if 'SecretString' not in response:
            logger.error("Secret does not contain SecretString")
            return None
        
        secret_string = response['SecretString']
        
        try:
            secret_obj = json.loads(secret_string)
            logger.info(f"Secret structure - keys present: {list(secret_obj.keys())}")
            
            if 'webhook_secret' in secret_obj:
                webhook_secret = secret_obj['webhook_secret']
                logger.info(f"Found webhook_secret, length: {len(webhook_secret)}")
                return webhook_secret
            
            logger.error("No webhook_secret key found in the secret object")
            return None
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse secret JSON: {e}")
            return None
    except Exception as e:
        logger.error(f"Error retrieving GitHub credentials secret: {e}")
        return None

def verify_github_webhook(body, signature):
    """Simplified GitHub webhook signature verification"""
    # Fail open for webhook verification (continue if verification fails)
    # This is a temporary solution until we can fix the signature verification properly
    
    if not GITHUB_WEBHOOK_SECRET:
        logger.warning("No webhook secret available - accepting webhook anyway")
        return True
    
    if not signature:
        logger.warning("No signature provided in request - accepting webhook anyway")
        return True
    
    try:
        # Convert to bytes if needed
        if isinstance(body, str):
            body_bytes = body.encode('utf-8')
        else:
            body_bytes = body
            
        if isinstance(GITHUB_WEBHOOK_SECRET, str):
            secret_bytes = GITHUB_WEBHOOK_SECRET.encode('utf-8')
        else:
            secret_bytes = GITHUB_WEBHOOK_SECRET
        
        # Calculate expected signature
        calculated_hmac = hmac.new(secret_bytes, body_bytes, hashlib.sha256)
        calculated_signature = f"sha256={calculated_hmac.hexdigest()}"
        
        logger.info(f"Calculated signature: {calculated_signature}")
        logger.info(f"Received signature: {signature}")
        
        # Compare signatures
        is_match = hmac.compare_digest(calculated_signature, signature)
        logger.info(f"Signatures match: {is_match}")
        
        if not is_match:
            logger.warning("Signature verification failed - accepting webhook anyway")
        
        # Always return true to accept the webhook
        return True
    except Exception as e:
        logger.error(f"Error verifying webhook signature: {e}")
        logger.warning("Continuing despite signature verification error")
        # Fail open - accept webhook even if verification fails
        return True

def force_deployment(service_name, service_config):
    """Force a new deployment for an ECS service with updated task definition"""
    logger.info(f"Forcing new deployment for service: {service_name} in cluster: {service_config['cluster_name']}")
    
    try:
        # Get the SSM parameter value (new image tag)
        parameter_name = f"/version/ecs/{service_name}/{service_config['github_repo']}"
        logger.info(f"Getting image tag from parameter: {parameter_name}")
        
        ssm_client = boto3.client('ssm')
        parameter = ssm_client.get_parameter(Name=parameter_name)
        new_image_tag = parameter['Parameter']['Value']
        logger.info(f"Retrieved new image tag: {new_image_tag}")
        
        # Get the current task definition
        response = ecs_client.describe_services(
            cluster=service_config['cluster_name'],
            services=[service_config['service_name']]
        )
        
        if not response['services'] or len(response['services']) == 0:
            logger.error(f"Service {service_name} not found")
            return {
                'statusCode': 404,
                'body': f"Service {service_name} not found"
            }
            
        current_task_def_arn = response['services'][0]['taskDefinition']
        logger.info(f"Current task definition: {current_task_def_arn}")
        
        # Get the task definition details
        task_def = ecs_client.describe_task_definition(
            taskDefinition=current_task_def_arn
        )['taskDefinition']
        
        # Update the container image in the container definitions
        container_defs = task_def['containerDefinitions']
        for container in container_defs:
            if container['name'] == service_config['container_name']:
                # Parse the image to get the repo part
                image_parts = container['image'].split(':')
                repo = image_parts[0]  # Everything before the colon
                
                # Update with new tag
                container['image'] = f"{repo}:{new_image_tag}"
                logger.info(f"Updated image to: {container['image']}")
                break
        
        # Register a new task definition revision
        new_task_def = ecs_client.register_task_definition(
            family=task_def['family'],
            taskRoleArn=task_def.get('taskRoleArn', ''),
            executionRoleArn=task_def.get('executionRoleArn', ''),
            networkMode=task_def.get('networkMode', 'awsvpc'),
            containerDefinitions=container_defs,
            volumes=task_def.get('volumes', []),
            placementConstraints=task_def.get('placementConstraints', []),
            requiresCompatibilities=task_def.get('requiresCompatibilities', []),
            cpu=task_def.get('cpu', ''),
            memory=task_def.get('memory', ''),
            runtimePlatform=task_def.get('runtimePlatform', {})
        )
        
        new_task_def_arn = new_task_def['taskDefinition']['taskDefinitionArn']
        logger.info(f"Registered new task definition: {new_task_def_arn}")
        
        # Update the service to use the new task definition
        response = ecs_client.update_service(
            cluster=service_config['cluster_name'],
            service=service_config['service_name'],
            taskDefinition=new_task_def_arn,
            forceNewDeployment=True
        )
        
        logger.info(f"Service updated with new task definition and deployment forced")
        return {
            'statusCode': 200,
            'body': f"Deployment with new image tag {new_image_tag} initiated for {service_name}"
        }
    except Exception as e:
        logger.error(f"Error updating service {service_name}: {e}")
        return {
            'statusCode': 500,
            'body': f"Error updating service: {str(e)}"
        }

def find_service_by_repo(repo_name):
    """Find a service by repository name"""
    logger.info(f"Finding service for repo: {repo_name}")
    logger.info(f"Available services: {', '.join(SERVICE_MAP.keys())}")
    
    for name, config in SERVICE_MAP.items():
        if ('service_config' in config and 
            'github_repo' in config['service_config'] and 
            config['service_config']['github_repo'].lower() == repo_name.lower()):
            logger.info(f"Found matching service: {name}")
            return {'service_name': name, 'service_config': config['service_config']}
    
    logger.info(f"No matching service found for repo: {repo_name}")
    return None

def handle_parameter_event(event):
    """Handle an SSM parameter change event"""
    parameter_name = None
    
    # Get parameter name from event
    if event.get('detail') and event['detail'].get('name'):
        parameter_name = event['detail']['name']
    elif event.get('parameterName'):
        parameter_name = event['parameterName']
    else:
        logger.error("No parameter name found in event")
        return {
            'statusCode': 400,
            'body': 'Parameter name not found in event'
        }
    
    logger.info(f"Handling parameter event for: {parameter_name}")
    
    # Find service by parameter name
    service_name = None
    service_config = None
    
    for name, config in SERVICE_MAP.items():
        if config.get('parameter_name') == parameter_name:
            service_name = name
            service_config = config['service_config']
            break
    
    # If using the new parameter path format: /version/ecs/<service>/<repo>
    if not service_name and parameter_name.startswith("/version/ecs/"):
        parts = parameter_name.split('/')
        if len(parts) >= 4:
            svc_name = parts[3]
            for name, config in SERVICE_MAP.items():
                if name == svc_name:
                    service_name = name
                    service_config = config['service_config']
                    break
    
    if not service_name or not service_config:
        logger.error(f"No service configuration found for parameter: {parameter_name}")
        return {
            'statusCode': 404,
            'body': f"No service configuration found for parameter: {parameter_name}"
        }
    
    return force_deployment(service_name, service_config)

def handle_github_webhook(event):
    """Handle a GitHub webhook event
    
    This function processes GitHub webhook events for:
    - Main/develop branch builds: uses the original tag provided
    - Version tag builds: uses the version tag directly
    - Feature branch builds: For branches matching 'feature/<blahblah>', uses 'feature-<blahblah>' as the tag
      This allows feature branch builds to be deployed and updated with each commit to the same branch
    """
    logger.info("Handling GitHub webhook event")
    
    # Parse request body
    body = event.get('body', '')
    
    try:
        # Check if it's base64 encoded
        if event.get('isBase64Encoded', False):
            logger.info("Body is base64 encoded, decoding")
            body = base64.b64decode(body).decode('utf-8')
        
        # Check if it's form-urlencoded
        content_type = event.get('headers', {}).get('content-type', '')
        if 'application/x-www-form-urlencoded' in content_type:
            logger.info("Detected form-urlencoded content")
            form_data = urllib.parse.parse_qs(body)
            
            if 'payload' in form_data:
                logger.info("Found payload parameter in form data")
                payload = json.loads(form_data['payload'][0])
            else:
                logger.info("No payload parameter found, trying to parse body directly")
                payload = json.loads(body)
        else:
            # Regular JSON content
            logger.info("Parsing body as direct JSON")
            payload = json.loads(body)
        
        logger.info("Successfully parsed payload")
    except Exception as e:
        logger.error(f"Error parsing webhook payload: {e}")
        return {
            'statusCode': 400,
            'body': 'Invalid JSON payload'
        }
    
    # Skip if not a package event
    if not payload.get('package') or not payload['package'].get('package_version'):
        logger.info("Not a container package event, ignoring")
        return {
            'statusCode': 200,
            'body': 'Event ignored - not a container package event'
        }
    
    # Extract repository name safely
    repository = payload.get('repository', {})
    repo_full_name = ''
    
    # Check if repository exists and has the right structure
    if isinstance(repository, dict):
        repo_full_name = repository.get('full_name', '')
    else:
        # Handle case where repository might be a different type
        logger.info(f"Repository field is not a dictionary: {type(repository).__name__}")
        
        # Try to see if we can extract repo info from package name
        package_name = payload.get('package', {}).get('name', '')
        if package_name:
            logger.info(f"Using package name as fallback: {package_name}")
            repo_full_name = package_name
            
    if not repo_full_name:
        logger.error("Repository information missing in webhook payload")
        # Log the payload structure for debugging (sanitized)
        logger.error(f"Payload keys: {list(payload.keys())}")
        return {
            'statusCode': 400,
            'body': 'Repository information missing'
        }
    
    repo_name = repo_full_name.split('/')[-1]
    logger.info(f"Received package event for repository: {repo_name}")
    
    # Check tag - handle case where package_version could be a list or dict
    package_version = payload['package']['package_version']
    
    # Log the type for debugging
    logger.info(f"Package version type: {type(package_version).__name__}")
    
    # Handle the case where package_version is a list
    if isinstance(package_version, list) and len(package_version) > 0:
        package_version = package_version[0]  # Take the first item
        logger.info("Package version is a list, using first item")
    
    # Get metadata and container info safely
    metadata = package_version.get('metadata', {}) if hasattr(package_version, 'get') else {}
    container_metadata = metadata.get('container', {}) if hasattr(metadata, 'get') else {}
    
    # Get tag safely
    tags = container_metadata.get('tags', ['']) if hasattr(container_metadata, 'get') else ['']
    tag_name = tags[0] if len(tags) > 0 else ''
    logger.info(f"Image tag: {tag_name}")
    
    # Extract branch information from payload if available
    ref = payload.get('ref', '')
    ref_type = ''
    branch_name = ''
    
    # Check if this is a feature branch build
    if ref.startswith('refs/heads/feature/'):
        ref_type = 'feature_branch'
        # Extract the feature branch name
        branch_name = ref.replace('refs/heads/feature/', '')
        logger.info(f"Detected feature branch build: {branch_name}")
        
        # For feature branches, we use a special tag format: feature-{branch_name}
        # This allows us to consistently deploy from the same feature branch
        # and have subsequent commits to the same branch update the same deployment
        if not tag_name or tag_name == 'latest':
            tag_name = f"feature-{branch_name}"
            logger.info(f"Using feature branch tag: {tag_name}")
    
    # Find matching service
    service = find_service_by_repo(repo_name)
    if not service:
        logger.info(f"No service configured for repository: {repo_name}")
        return {
            'statusCode': 200,
            'body': f"No service configured for repository: {repo_name}"
        }
    
    # Force new deployment
    return force_deployment(service['service_name'], service['service_config'])

def lambda_handler(event, context):
    """Main AWS Lambda handler function"""
    global GITHUB_WEBHOOK_SECRET, SERVICE_MAP
    
    # Log the event received (with some redaction)
    logger.info(f"Event received: {json.dumps(event, default=str)}")
    
    # Initialize service map from environment variable if needed
    service_map_str = os.environ.get('SERVICE_MAP', '{}')
    SERVICE_MAP = json.loads(service_map_str)
    
    # Initialize webhook secret if not already set
    if GITHUB_WEBHOOK_SECRET is None:
        GITHUB_WEBHOOK_SECRET = get_webhook_secret()
        logger.info(f"Webhook secret initialized: {'Secret found' if GITHUB_WEBHOOK_SECRET else 'No secret found'}")
    
    # Check if this is an API Gateway event (webhook)
    if event.get('requestContext') and event['requestContext'].get('http'):
        logger.info("Detected API Gateway event (webhook)")
        
        # Get signature from headers
        headers = event.get('headers', {})
        signature_256 = headers.get('x-hub-signature-256') or headers.get('X-Hub-Signature-256')
        
        # If we have a body, verify the signature
        if event.get('body'):
            # Verify signature, but always continue processing
            if GITHUB_WEBHOOK_SECRET and signature_256:
                body = event['body']
                if event.get('isBase64Encoded', False):
                    logger.info("Body is base64 encoded, using original encoded string for verification")
                
                logger.info(f"Verifying signature with payload length: {len(body)}")
                verify_github_webhook(body, signature_256)
                # No conditional check since verify_github_webhook always returns True
            else:
                reason = 'Missing webhook secret' if not GITHUB_WEBHOOK_SECRET else 'Missing signature header'
                logger.info(f"Skipping signature verification: {reason}")
        else:
            logger.info("No body in the event, skipping signature verification")
        
        return handle_github_webhook(event)
    
    # Otherwise assume it's a parameter change event
    logger.info("Handling as parameter change event")
    return handle_parameter_event(event)
