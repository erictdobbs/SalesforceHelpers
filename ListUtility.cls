global without sharing class ListUtility {

    // Given a list of objects, find one with the given ID
    public static sObject FindById(List<sObject> objectList, String id) {
        for (sObject obj : objectList) if (obj.Id == id) return obj;
        return null;
    }
    
    public static List<String> GetIds(List<sObject> objectList) {
        List<String> ret = new List<String>();
        for (sObject obj : objectList) ret.Add(obj.Id);
        return ret;
    }
    
    public static boolean ListContains(List<String> myList, String key) {
        for (String element : myList)
            if (element == key) return true;
        return false;
    }

}