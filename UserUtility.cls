global without sharing class UserUtility {
    
    /* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
     * 
     * UserUtility.apxc
     * 
     * This class contains methods for navigating the twisting nested structure of groups and 
     * roles. Groups and UserRoles can be nested within each other, making something seemingly
     * simple such as finding all users in a group surprisingly annoying. 
     * 
     * Depends on ListUtility.apxc
     * 
     * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

    public static List<User> GetUsersByRoleId(string roleId) {
        List<User> matchingUsers = [SELECT Email,Id,Name,UserRoleId  FROM User WHERE UserRoleId =: roleId];
        return matchingUsers;
    }
    
    
    public static boolean IsUserInGroupByGroupName(string userId, string groupName) {
        List<User> usersInGroup = GetUsersByGroupName(groupName);
        List<String> userIds = ListUtility.GetIds(usersInGroup);
        return ListUtility.ListContains(userIds, userId);
    }

    
    public static List<User> GetUsersByGroupName(string groupName) {
        List<Group> allGroups = [SELECT DeveloperName,Id,Name,RelatedId,Type FROM Group];
        List<GroupMember> allGroupMembers = [SELECT GroupId,Id,SystemModstamp,UserOrGroupId FROM GroupMember];
        List<User> allUsers = [SELECT Email,Id,Name,UserRoleId  FROM User];
        List<UserRole> allUserRoles = [SELECT Id,ParentRoleId FROM UserRole];
        return GetUsersByGroupName(groupName, allGroups, allGroupMembers, allUsers, allUserRoles);
    }
    public static List<User> GetUsersByGroupName(string groupName, List<Group> allGroups, List<GroupMember> allGroupMembers, List<User> allUsers, List<UserRole> allUserRoles) {
        String groupId = '';
        for (Group g : allGroups) if (g.Name == groupName) groupId = g.Id;
        return GetUsersByGroupId(groupId, allGroups, allGroupMembers, allUsers, allUserRoles);
    }

    
    public static List<User> GetUsersByGroupId(string groupId) {
        // Given a group ID, find all users under it (accounts for nested groups)
        List<Group> allGroups = [SELECT DeveloperName,Id,Name,RelatedId,Type FROM Group];
        List<GroupMember> allGroupMembers = [SELECT GroupId,Id,SystemModstamp,UserOrGroupId FROM GroupMember];
        List<User> allUsers = [SELECT Email,Id,Name,UserRoleId  FROM User];
        List<UserRole> allUserRoles = [SELECT Id,ParentRoleId FROM UserRole];
        return GetUsersByGroupId(groupId, allGroups, allGroupMembers, allUsers, allUserRoles);
    }
    public static List<User> GetUsersByGroupId(string groupId, List<Group> allGroups, List<GroupMember> allGroupMembers, List<User> allUsers, List<UserRole> allUserRoles) {
        List<User> matchingUsers = new List<User>();        
        List<Group> groups = new List<Group>();
        
        for ( Group checkGroup : allGroups) 
            if (checkGroup.Id == groupId)
                groups.Add(checkGroup);
        
        while(groups.size() > 0) {
            Group iterGroup = groups.remove(0);
            for (GroupMember gm : allGroupMembers) 
                if (gm.GroupId == iterGroup.Id) {
                    User matchingUser = (User)ListUtility.FindById(allUsers, gm.UserOrGroupId);
                    if (matchingUser != null) 
                        matchingUsers.Add(matchingUser);
                    
                    Group matchingGroup = (Group)ListUtility.FindById(allGroups, gm.UserOrGroupId);
                    if (matchingGroup != null)
                        groups.Add(matchingGroup);  
                }
            
            List<String> roleIds = new List<String>();
            if (iterGroup.Type == 'Role')
                roleIds.Add(iterGroup.RelatedId);
            if (iterGroup.Type == 'RoleAndSubordinates') {
                List<UserRole> roleAndSubs = GetRoleAndSubordinates(allUserRoles, iterGroup.RelatedId);
                List<String> roleAndSubIds = ListUtility.GetIds(roleAndSubs);
                roleIds.AddAll(roleAndSubIds);
            }
            if (roleIds.size() > 0) 
                for (User user : allUsers) 
                    if (ListUtility.ListContains(roleIds, user.UserRoleId))
                        matchingUsers.Add(user);
        }
        
        // Filter out duplicates
        return new List<User>(new Set<User>(matchingUsers));
    }
    
    
    public static List<Group> GetGroupsByUserId(String userId) { 
        // Given a user ID, find all groups the user belongs to (accounts for nested groups)
        User user = [SELECT Email,Id,Name,UserRoleId FROM User WHERE Id =: userId];
        List<Group> allGroups = [SELECT DeveloperName,Id,Name,RelatedId,Type FROM Group];
        List<GroupMember> allGroupMembers = [SELECT GroupId,Id,SystemModstamp,UserOrGroupId FROM GroupMember];
        List<UserRole> allUserRoles = [SELECT Id,ParentRoleId FROM UserRole];        
        return GetGroupsByUserId(userId, user, allGroups, allGroupMembers, allUserRoles);
    }
    public static List<Group> GetGroupsByUserId(String userId, User user, List<Group> allGroups, List<GroupMember> allGroupMembers, List<UserRole> allUserRoles) {       
        List<Group> matchingGroups = new List<Group>();
        
        for (GroupMember gm : allGroupMembers) {
            if (gm.UserOrGroupId == userId) {
                Group matchingGroup = (Group)ListUtility.FindById(allGroups, gm.GroupId);
                matchingGroups.Add(matchingGroup);
            }
        }
        
        List<UserRole> superiorRoles = GetRoleAndSuperiors(allUserRoles, user.UserRoleId);
        for (Group g : allGroups) {
            if (g.Type == 'Role' && g.RelatedId == user.UserRoleId) 
                    matchingGroups.Add(g);
            if (g.Type == 'RoleAndSubordinates' && ListUtility.FindById(superiorRoles, g.RelatedId) != null)
                    matchingGroups.Add(g);
        }
        
        integer groupIndex = 0;
        while (groupIndex < matchingGroups.size()) {
            GroupMember gm = GetGroupMemberByUserOrGroupId(allGroupMembers, matchingGroups[groupIndex].Id);
            if (gm != null) {
                Group superiorGroup = (Group)ListUtility.FindById(allGroups, gm.GroupId);
                if (superiorGroup != null) matchingGroups.add(superiorGroup);
            }
            groupIndex += 1;
        }
        
        
        Set<Group> ret = new Set<Group>();
        for (Group g : matchingGroups) {
            if (g.Type == 'Regular')
                ret.Add(g);
        }
        
        // Filter out duplicates
        return new List<Group>(ret);
    }

    
    public static List<UserRole> GetRoleAndSubordinates(List<UserRole> allRoles, string targetId) {
        // Generate a list of the role and all its subordinate roles
        List<UserRole> roles = new List<UserRole>();
        roles.Add((UserRole)ListUtility.FindById(allRoles, targetId));
        
        integer numSearched = 0;
        while (numSearched < roles.size()) {
            for (UserRole iterRole : allRoles) 
                if (iterRole.ParentRoleId == roles[numSearched].Id)
                    roles.Add(iterRole);
            numSearched += 1;
        }
        return roles;
    }
    
    
    public static List<UserRole> GetRoleAndSuperiors(List<UserRole> allRoles, string targetId) {
        // Generate a list of the role and all its managing roles
        List<UserRole> roles = new List<UserRole>();
        roles.Add((UserRole)ListUtility.FindById(allRoles, targetId));
        
        integer numSearched = 0;
        while (numSearched < roles.size()) {
            for (UserRole iterRole : allRoles) 
                if (iterRole.Id == roles[numSearched].ParentRoleId)
                    roles.Add(iterRole);
            numSearched += 1;
        }
        return roles;
    }
    
    
    public static List<String> GetEmailsFromUsers(List<User> users) {
        // Given a list of users, generate a list of email addresses
        List<String> ret = new List<String>();
        for (User user : users) ret.Add(user.Email);
        return ret;
    }
    
    
    public static GroupMember GetGroupMemberByUserOrGroupId(List<GroupMember> allGroupMembers, string userOrGroupId) {
        for (GroupMember gm : allGroupMembers)
            if (gm.UserOrGroupId == userOrGroupId) 
            return gm;
        return null;
    }

}