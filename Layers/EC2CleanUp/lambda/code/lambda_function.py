import boto3
import os
import logging

from datetime import datetime, timedelta, timezone
from botocore.exceptions import ClientError


logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2_client = boto3.client('ec2')

RETENTION_DAYS = int(os.environ.get('RETENTION_DAYS', 365))
EXCLUDE_TAG_KEY = os.environ.get('EXCLUDE_TAG_KEY', '')
EXCLUDE_TAG_VALUE = os.environ.get('EXCLUDE_TAG_VALUE', '')
AWS_REGION = os.environ.get('AWS_REGION', 'us-west-2')


def is_snapshot_old(snapshot_start_time):
    cutoff_date = datetime.now(timezone.utc) - timedelta(days=RETENTION_DAYS)
    return snapshot_start_time < cutoff_date


def should_exclude_snapshot(snapshot_tags):
    if not EXCLUDE_TAG_KEY or not EXCLUDE_TAG_VALUE:
        return False
    if not snapshot_tags:
        return False
    tags_dict = {tag['Key']: tag['Value'] for tag in snapshot_tags}

    if EXCLUDE_TAG_KEY in tags_dict:
        return tags_dict[EXCLUDE_TAG_KEY] == EXCLUDE_TAG_VALUE
    
    return False


def get_all_snapshots():
    try:
        snapshots = []
        paginator = ec2_client.get_paginator('describe_snapshots')
        page_iterator = paginator.paginate(OwnerIds=['self'])
        
        for page in page_iterator:
            snapshots.extend(page['Snapshots'])
        
        logger.info(f"Found {len(snapshots)} total snapshots in region {AWS_REGION}")
        return snapshots
    
    except ClientError as e:
        logger.error(f"Error retrieving snapshots: {str(e)}")
        raise


def delete_snapshot(snapshot_id):
    try:
        ec2_client.delete_snapshot(SnapshotId=snapshot_id)
        logger.info(f"Successfully deleted snapshot: {snapshot_id}")
        return True
    
    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_message = e.response['Error']['Message']
        
        if error_code == 'InvalidSnapshot.InUse':
            logger.warning(f"Snapshot {snapshot_id} is in use and cannot be deleted: {error_message}")
        elif error_code == 'InvalidSnapshot.NotFound':
            logger.warning(f"Snapshot {snapshot_id} not found (may have been already deleted): {error_message}")
        else:
            logger.error(f"Error deleting snapshot {snapshot_id}: {error_code} - {error_message}")
        
        return False


def lambda_handler(event, context):

    logger.info(f"Starting snapshot cleanup process. Retention period: {RETENTION_DAYS} days")
    logger.info(f"Exclusion tag: {EXCLUDE_TAG_KEY}={EXCLUDE_TAG_VALUE}" if EXCLUDE_TAG_KEY else "No exclusion tags configured")
    
    try:
        all_snapshots = get_all_snapshots()
        
        if not all_snapshots:
            logger.info("No snapshots found in the region")
            return {
                'statusCode': 200,
                'total_snapshots': 0,
                'old_snapshots_found': 0,
                'snapshots_deleted': 0,
                'snapshots_failed': 0,
                'message': 'No snapshots found'
            }
        old_snapshots = []
        current_time = datetime.now(timezone.utc)
        cutoff_date = current_time - timedelta(days=RETENTION_DAYS)
        
        for snapshot in all_snapshots:
            snapshot_id = snapshot['SnapshotId']
            start_time = snapshot['StartTime']
            if is_snapshot_old(start_time):
                tags = snapshot.get('Tags', [])
                if not should_exclude_snapshot(tags):
                    old_snapshots.append(snapshot)
                    logger.info(f"Found old snapshot: {snapshot_id} (created: {start_time}, age: {(current_time - start_time).days} days)")
                else:
                    logger.info(f"Excluding snapshot {snapshot_id} due to exclusion tag")
        
        logger.info(f"Found {len(old_snapshots)} snapshots older than {RETENTION_DAYS} days")
        deleted_count = 0
        failed_count = 0
        deleted_snapshots = []
        failed_snapshots = []
        
        for snapshot in old_snapshots:
            snapshot_id = snapshot['SnapshotId']
            if delete_snapshot(snapshot_id):
                deleted_count += 1
                deleted_snapshots.append(snapshot_id)
            else:
                failed_count += 1
                failed_snapshots.append(snapshot_id)
        result = {
            'statusCode': 200,
            'total_snapshots': len(all_snapshots),
            'old_snapshots_found': len(old_snapshots),
            'snapshots_deleted': deleted_count,
            'snapshots_failed': failed_count,
            'cutoff_date': cutoff_date.isoformat(),
            'timestamp': current_time.isoformat()
        }
        
        if deleted_snapshots:
            result['deleted_snapshot_ids'] = deleted_snapshots[:10]  
            if len(deleted_snapshots) > 10:
                result['message'] = f"Deleted {deleted_count} snapshots (showing first 10 IDs)"
            else:
                result['message'] = f"Successfully deleted {deleted_count} snapshots"
        else:
            result['message'] = "No snapshots were deleted"
        
        if failed_snapshots:
            result['failed_snapshot_ids'] = failed_snapshots[:10] 
            logger.warning(f"Failed to delete {failed_count} snapshots")
        
        logger.info(f"Cleanup completed. Deleted: {deleted_count}, Failed: {failed_count}")
        
        return result
    
    except Exception as e:
        logger.error(f"Unexpected error in lambda_handler: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'error': str(e),
            'message': 'An error occurred during snapshot cleanup'
        }

